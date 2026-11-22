#include "api.hpp"
#include "mailer.hpp"

#include <algorithm>
#include <cctype>
#include <future>
#include <unordered_set>
#include <thread>

namespace stockroom {
namespace {
using namespace drogon;

Json::Value receipt(const std::shared_ptr<orm::DbClient> &client,
                    const std::string &loanId) {
    const auto rows = client->execSqlSync(
        "SELECT l.id AS loan_id,r.receipt_number,"
        "DATE_FORMAT(l.borrowed_at,'%Y-%m-%dT%H:%i:%s.%fZ') AS borrowed_at,"
        "DATE_FORMAT(l.due_at,'%Y-%m-%dT%H:%i:%s.%fZ') AS due_at,"
        "IF(l.returned_at IS NULL,NULL,DATE_FORMAT(l.returned_at,'%Y-%m-%dT%H:%i:%s.%fZ')) AS returned_at,"
        "CASE WHEN l.status='ACTIVE' AND l.due_at<UTC_TIMESTAMP(6) THEN 'OVERDUE' ELSE l.status END AS loan_status,"
        "u.id AS unit_record_id,u.serial AS barcode,u.equipment_id,e.name AS equipment_name,"
        "usr.name AS borrower_name,usr.account_id AS borrower_id,usr.role AS account_type,usr.email "
        "FROM loans l JOIN receipts r ON r.loan_id=l.id JOIN units u ON u.id=l.unit_id "
        "JOIN equipment e ON e.id=u.equipment_id JOIN users usr ON usr.id=l.user_id WHERE l.id=?",
        loanId);
    if (rows.empty()) throw std::runtime_error("Loan receipt was not found");
    const auto &row = rows[0];
    Json::Value out;
    out["loan_id"] = row["loan_id"].as<std::string>();
    out["receipt_number"] = row["receipt_number"].as<std::string>();
    out["borrowed_at"] = row["borrowed_at"].as<std::string>();
    out["due_at"] = row["due_at"].as<std::string>();
    out["returned_at"] = row["returned_at"].isNull() ? Json::Value() : Json::Value(row["returned_at"].as<std::string>());
    out["loan_status"] = row["loan_status"].as<std::string>();
    out["unit_record_id"] = row["unit_record_id"].as<std::string>();
    out["barcode"] = row["barcode"].as<std::string>();
    out["equipment_id"] = row["equipment_id"].as<std::string>();
    out["equipment_name"] = row["equipment_name"].as<std::string>();
    out["borrower_name"] = row["borrower_name"].as<std::string>();
    out["borrower_id"] = row["borrower_id"].as<std::string>();
    out["account_type"] = row["account_type"].as<std::string>();
    out["email"] = row["email"].as<std::string>();
    return out;
}

std::string bodyString(const Json::Value &body, const char *key) {
    return body.isMember(key) && body[key].isString() ? body[key].asString() : "";
}

bool requireUser(const HttpRequestPtr &request, Callback &callback, Json::Value &user) {
    try { user = currentUser(request); return true; }
    catch (const std::runtime_error &e) { callback(error(k401Unauthorized, e.what())); }
    catch (...) { callback(error(k500InternalServerError, "Unable to verify account")); }
    return false;
}

void storeEvent(const std::shared_ptr<orm::Transaction> &tx,
                const std::string &eventType,
                const Json::Value &data) {
    Json::Value event;
    event["type"] = eventType;
    event["data"] = data;
    Json::StreamWriterBuilder writer;
    tx->execSqlSync(
        "INSERT INTO outbox_events(event_type,payload,created_at) VALUES(?,?,UTC_TIMESTAMP(6))",
        eventType, Json::writeString(writer, event));
}

void commit(std::shared_ptr<orm::Transaction> &tx) {
    auto done = std::make_shared<std::promise<bool>>();
    auto result = done->get_future();
    tx->setCommitCallback([done](bool ok) { done->set_value(ok); });
    tx.reset();
    if (result.wait_for(std::chrono::seconds(10)) != std::future_status::ready || !result.get())
        throw std::runtime_error("Transaction could not be committed");
}

std::string dueToMysqlUtc(const std::string &iso) {
    if (iso.size() < 20 || iso.back() != 'Z' || iso[10] != 'T')
        throw std::runtime_error("Return date must be in the future and include timezone");
    auto value = iso.substr(0, iso.size() - 1);
    value[10] = ' ';
    const auto dot = value.find('.');
    if (dot == std::string::npos) value += ".000000";
    else {
        auto fraction = value.substr(dot + 1);
        if (fraction.size() > 6) fraction.resize(6);
        while (fraction.size() < 6) fraction.push_back('0');
        value.resize(dot + 1);
        value += fraction;
    }
    return value;
}

std::string htmlEscape(const std::string &raw) {
    std::string result;
    for (char ch : raw) {
        if (ch == '&') result += "&amp;";
        else if (ch == '<') result += "&lt;";
        else if (ch == '>') result += "&gt;";
        else if (ch == '"') result += "&quot;";
        else result += ch;
    }
    return result;
}
}

void registerLoanRoutes() {
    using namespace drogon;
    app().registerHandler(
        "/loans",
        [](const HttpRequestPtr &request, Callback &&callback) {
            Json::Value user;
            if (!requireUser(request, callback, user)) return;
            const auto body = request->getJsonObject();
            if (!body) { callback(error(k400BadRequest, "Invalid JSON body")); return; }
            const auto unitId = bodyString(*body, "unit_id");
            const auto key = bodyString(*body, "idempotency_key");
            const auto requestedBorrower = bodyString(*body, "borrower_id");
            if (!requestedBorrower.empty() && user["role"].asString() != "ADMIN") {
                callback(error(k403Forbidden, "Only administrators can issue for another borrower")); return;
            }
            std::string due;
            try { due = dueToMysqlUtc(bodyString(*body, "due_at")); }
            catch (const std::runtime_error &e) { callback(error(k422UnprocessableEntity, e.what())); return; }
            if (unitId.empty() || key.empty() || key.size() > 128) {
                callback(error(k422UnprocessableEntity, "A scanned item and idempotency key are required")); return;
            }
            try {
                auto db = app().getDbClient();
                auto tx = db->newTransaction();
                const auto borrowerId = requestedBorrower.empty() ? user["id"].asString() : requestedBorrower;
                if (!requestedBorrower.empty()) {
                    const auto borrower = tx->execSqlSync(
                        "SELECT id FROM users WHERE id=? AND role='STUDENT' AND deleted_at IS NULL "
                        "AND email_verified_at IS NOT NULL AND account_status='ACTIVE'", borrowerId);
                    if (borrower.empty()) {
                        callback(error(k422UnprocessableEntity, "Choose an active verified student")); return;
                    }
                }
                const auto duplicate = tx->execSqlSync(
                    "SELECT loan_id FROM transactions WHERE idempotency_key=?", key);
                if (!duplicate.empty() && !duplicate[0]["loan_id"].isNull()) {
                    const auto prior = receipt(tx, duplicate[0]["loan_id"].as<std::string>());
                    tx.reset();
                    callback(json(prior));
                    return;
                }
                const auto dueCheck = tx->execSqlSync(
                    "SELECT STR_TO_DATE(?,'%Y-%m-%d %H:%i:%s.%f')>UTC_TIMESTAMP(6) AS valid", due);
                if (dueCheck.empty() || dueCheck[0]["valid"].isNull() || dueCheck[0]["valid"].as<int>() != 1) {
                    callback(error(k422UnprocessableEntity, "Return date must be in the future")); return;
                }
                const auto units = tx->execSqlSync(
                    "SELECT u.id,u.serial,u.status,u.equipment_id FROM units u WHERE u.id=? FOR UPDATE", unitId);
                if (units.empty()) { callback(error(k404NotFound, "Scanned item was not found")); return; }
                if (units[0]["status"].as<std::string>() != "AVAILABLE") {
                    callback(error(k409Conflict, "This unit is not available")); return;
                }
                const auto loanId = utils::getUuid();
                auto compact = loanId;
                compact.erase(std::remove(compact.begin(), compact.end(), '-'), compact.end());
                std::transform(compact.begin(), compact.end(), compact.begin(),
                               [](unsigned char ch) { return static_cast<char>(std::toupper(ch)); });
                const auto receiptNumber = "LOAN-" + compact.substr(0, 8);
                tx->execSqlSync("UPDATE units SET status='ISSUED' WHERE id=? AND status='AVAILABLE'", unitId);
                const auto now = tx->execSqlSync("SELECT ROW_COUNT() AS changed");
                if (now.empty() || now[0]["changed"].as<int>() != 1) {
                    callback(error(k409Conflict, "This unit was just borrowed by another user")); return;
                }
                tx->execSqlSync(
                    "INSERT INTO loans(id,user_id,unit_id,borrowed_at,due_at,returned_at,status) "
                    "VALUES(?,?,?,UTC_TIMESTAMP(6),STR_TO_DATE(?,'%Y-%m-%d %H:%i:%s.%f'),NULL,'ACTIVE')",
                    loanId, borrowerId, unitId, due);
                tx->execSqlSync("INSERT INTO receipts(loan_id,receipt_number,created_at) VALUES(?,?,UTC_TIMESTAMP(6))",
                                loanId, receiptNumber);
                tx->execSqlSync(
                    "INSERT INTO transactions(id,equipment_id,unit_id,loan_id,type,quantity,created_at,actor_id,idempotency_key) "
                    "VALUES(?,?,?,?,'ISSUE',1,UTC_TIMESTAMP(6),?,?)",
                    utils::getUuid(), units[0]["equipment_id"].as<std::string>(), unitId, loanId,
                    user["id"].asString(), key);
                const auto result = receipt(tx, loanId);
                storeEvent(tx, "loan", result);
                commit(tx);
                const auto email = result["email"].asString();
                const auto number = result["receipt_number"].asString();
                const auto details = "ENcoRE loan receipt\nReceipt: " + number +
                    "\nBorrower: " + result["borrower_name"].asString() +
                    "\nStudent / User ID: " + result["borrower_id"].asString() +
                    "\nEquipment: " + result["equipment_name"].asString() +
                    "\nItem serial: " + result["barcode"].asString() +
                    "\nBorrowed: " + result["borrowed_at"].asString() +
                    "\nReturn by: " + result["due_at"].asString() +
                    "\nStatus: ACTIVE\n";
                const auto html = std::string("<!doctype html><html><meta charset='utf-8'><style>body{font:14px Arial;max-width:380px;margin:36px auto;color:#0f0f0f}h1{text-align:center;color:#0b3d2e;font-size:22px}small{display:block;text-align:center;margin-bottom:36px}table{width:100%;border-collapse:collapse}td{padding:12px 4px;border-bottom:1px solid #dce7df}td:first-child{font-weight:bold;width:42%}.due{margin-top:25px;padding:14px;background:#edf5ef;color:#0b3d2e}</style><h1>ENcoRE</h1><small>EQUIPMENT RECEIPT</small><table>") +
                    "<tr><td>Receipt</td><td>" + htmlEscape(number) + "</td></tr>" +
                    "<tr><td>Borrower</td><td>" + htmlEscape(result["borrower_name"].asString()) + "</td></tr>" +
                    "<tr><td>Student ID</td><td>" + htmlEscape(result["borrower_id"].asString()) + "</td></tr>" +
                    "<tr><td>Equipment</td><td>" + htmlEscape(result["equipment_name"].asString()) + "</td></tr>" +
                    "<tr><td>Item serial</td><td>" + htmlEscape(result["barcode"].asString()) + "</td></tr>" +
                    "<tr><td>Borrowed</td><td>" + htmlEscape(result["borrowed_at"].asString()) + "</td></tr>" +
                    "</table><div class='due'><strong>Return by:</strong> " +
                    htmlEscape(result["due_at"].asString()) + "</div></html>";
                std::thread([email, number, details, html]() {
                    if (!sendEmail(email, "ENcoRE loan receipt " + number,
                                   "Your item has been borrowed. Please return it by the time shown in the attached receipt.\n\n" + details,
                                   number + ".html", html))
                        LOG_ERROR << "Loan receipt email failed for " << number;
                }).detach();
                callback(json(result, k201Created));
            } catch (const drogon::orm::DrogonDbException &) {
                callback(error(k409Conflict, "Unit is unavailable or already has an active loan"));
            } catch (...) { callback(error(k500InternalServerError, "Unable to create loan")); }
        },
        {Post});

    app().registerHandler(
        "/returns/{1}",
        [](const HttpRequestPtr &request, Callback &&callback, const std::string &barcode) {
            Json::Value user;
            if (!requireUser(request, callback, user)) return;
            if (user["role"].asString() != "ADMIN") {
                callback(error(k403Forbidden, "An administrator must process returns")); return;
            }
            const auto body = request->getJsonObject();
            const auto condition = body ? bodyString(*body, "condition") : "GOOD";
            const auto requestedReturn = body ? bodyString(*body, "returned_at") : "";
            if (condition != "GOOD" && condition != "MAINTENANCE") {
                callback(error(k422UnprocessableEntity, "Choose a valid item condition")); return;
            }
            std::string returnTime;
            if (!requestedReturn.empty()) {
                try { returnTime = dueToMysqlUtc(requestedReturn); }
                catch (...) { callback(error(k422UnprocessableEntity, "Enter a valid return time")); return; }
            }
            try {
                auto db = app().getDbClient();
                auto tx = db->newTransaction();
                const auto units = tx->execSqlSync("SELECT id,equipment_id FROM units WHERE serial=? FOR UPDATE", barcode);
                if (units.empty()) { callback(error(k404NotFound, "Scanned item was not found")); return; }
                const auto loans = tx->execSqlSync(
                    "SELECT id,user_id FROM loans WHERE unit_id=? AND status IN ('ACTIVE','OVERDUE') FOR UPDATE",
                    units[0]["id"].as<std::string>());
                if (loans.empty()) { callback(error(k409Conflict, "This unit has no active loan")); return; }
                if (user["role"].asString() != "ADMIN" && loans[0]["user_id"].as<std::string>() != user["id"].asString()) {
                    callback(error(k403Forbidden, "Only the borrower or an administrator can return this unit")); return;
                }
                const auto loanId = loans[0]["id"].as<std::string>();
                if (!returnTime.empty()) {
                    const auto valid = tx->execSqlSync(
                        "SELECT STR_TO_DATE(?,'%Y-%m-%d %H:%i:%s.%f')>=borrowed_at "
                        "AND STR_TO_DATE(?,'%Y-%m-%d %H:%i:%s.%f')<=UTC_TIMESTAMP(6)+INTERVAL 1 MINUTE AS valid "
                        "FROM loans WHERE id=?", returnTime, returnTime, loanId);
                    if (valid.empty() || valid[0]["valid"].isNull() || valid[0]["valid"].as<int>() != 1) {
                        callback(error(k422UnprocessableEntity, "Return time must follow borrowing and cannot be in the future")); return;
                    }
                }
                const auto receiveKey = "return-" + loanId;
                const auto prior = tx->execSqlSync("SELECT id FROM transactions WHERE idempotency_key=?", receiveKey);
                if (prior.empty()) {
                    if (returnTime.empty())
                        tx->execSqlSync("UPDATE loans SET status='RETURNED',returned_at=UTC_TIMESTAMP(6) WHERE id=?", loanId);
                    else
                        tx->execSqlSync("UPDATE loans SET status='RETURNED',returned_at=STR_TO_DATE(?,'%Y-%m-%d %H:%i:%s.%f') WHERE id=?", returnTime, loanId);
                    tx->execSqlSync("UPDATE units SET status=? WHERE id=?",
                        condition == "GOOD" ? "AVAILABLE" : "MAINTENANCE", units[0]["id"].as<std::string>());
                    tx->execSqlSync(
                        "INSERT INTO transactions(id,equipment_id,unit_id,loan_id,type,quantity,created_at,actor_id,idempotency_key) "
                        "VALUES(?,?,?,?,'RECEIVE',1,UTC_TIMESTAMP(6),?,?)",
                        utils::getUuid(), units[0]["equipment_id"].as<std::string>(), units[0]["id"].as<std::string>(),
                        loanId, user["id"].asString(), receiveKey);
                }
                const auto result = receipt(tx, loanId);
                storeEvent(tx, "return", result);
                commit(tx);
                callback(json(result));
            } catch (const drogon::orm::DrogonDbException &) {
                callback(error(k409Conflict, "Unable to complete return"));
            } catch (...) { callback(error(k500InternalServerError, "Unable to complete return")); }
        },
        {Post});

    app().registerHandler(
        "/receipts",
        [](const HttpRequestPtr &request, Callback &&callback) {
            Json::Value user;
            if (!requireUser(request, callback, user)) return;
            try {
                const bool isAdmin = user["role"].asString() == "ADMIN";
                const auto rows = isAdmin
                    ? app().getDbClient()->execSqlSync("SELECT id FROM loans ORDER BY borrowed_at DESC")
                    : app().getDbClient()->execSqlSync("SELECT id FROM loans WHERE user_id=? ORDER BY borrowed_at DESC", user["id"].asString());
                Json::Value result(Json::arrayValue);
                for (const auto &row : rows) result.append(receipt(app().getDbClient(), row["id"].as<std::string>()));
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to load receipts")); }
        },
        {Get});

    app().registerHandler(
        "/notifications",
        [](const HttpRequestPtr &request, Callback &&callback) {
            Json::Value user;
            if (!requireUser(request, callback, user)) return;
            try {
                const auto rows = app().getDbClient()->execSqlSync(
                    "SELECT CONCAT('borrow-',l.id) AS id,'borrowed' AS type,"
                    "CONCAT('Borrowed ',e.name) AS title,"
                    "CONCAT('Item ',u.serial,' was checked out.') AS message,"
                    "l.borrowed_at AS created_at FROM loans l "
                    "JOIN units u ON u.id=l.unit_id JOIN equipment e ON e.id=u.equipment_id "
                    "WHERE l.user_id=? UNION ALL "
                    "SELECT CONCAT('return-',l.id),'returned',"
                    "CONCAT('Returned ',e.name),CONCAT('Item ',u.serial,' was returned.'),"
                    "l.returned_at FROM loans l JOIN units u ON u.id=l.unit_id "
                    "JOIN equipment e ON e.id=u.equipment_id "
                    "WHERE l.user_id=? AND l.returned_at IS NOT NULL UNION ALL "
                    "SELECT CONCAT('overdue-',l.id),'overdue',"
                    "CONCAT('Overdue: ',e.name),CONCAT('Return item ',u.serial,' as soon as possible.'),"
                    "l.due_at FROM loans l JOIN units u ON u.id=l.unit_id "
                    "JOIN equipment e ON e.id=u.equipment_id "
                    "WHERE l.user_id=? AND l.status IN ('ACTIVE','OVERDUE') "
                    "AND l.due_at<UTC_TIMESTAMP(6) ORDER BY created_at DESC LIMIT 100",
                    user["id"].asString(), user["id"].asString(), user["id"].asString());
                Json::Value result(Json::arrayValue);
                const auto readRows = app().getDbClient()->execSqlSync(
                    "SELECT notification_id FROM notification_reads WHERE user_id=?", user["id"].asString());
                std::unordered_set<std::string> readIds;
                for (const auto &readRow : readRows) readIds.insert(readRow["notification_id"].as<std::string>());
                for (const auto &row : rows) {
                    Json::Value item;
                    for (const auto *key : {"id", "type", "title", "message", "created_at"})
                        item[key] = row[key].as<std::string>();
                    item["is_read"] = readIds.find(item["id"].asString()) != readIds.end();
                    result.append(item);
                }
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to load notifications")); }
        },
        {Get});

    app().registerHandler(
        "/notifications/{1}/read",
        [](const HttpRequestPtr &request, Callback &&callback, const std::string &notificationId) {
            Json::Value user;
            if (!requireUser(request, callback, user)) return;
            if (notificationId.size() > 64 || notificationId.empty()) {
                callback(error(k422UnprocessableEntity, "Invalid notification")); return;
            }
            try {
                app().getDbClient()->execSqlSync(
                    "INSERT IGNORE INTO notification_reads(user_id,notification_id,read_at) VALUES(?,?,UTC_TIMESTAMP(6))",
                    user["id"].asString(), notificationId);
                Json::Value result;
                result["is_read"] = true;
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to mark notification read")); }
        }, {Post});
}
}
