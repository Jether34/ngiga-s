#include "api.hpp"

#include <algorithm>
#include <future>
#include <regex>

namespace stockroom {
namespace {
using namespace drogon;

bool admin(const Json::Value &user) { return user["role"].asString() == "ADMIN"; }

Json::Value asInventory(const drogon::orm::Row &row) {
    Json::Value item;
    item["id"] = row["id"].as<std::string>();
    item["name"] = row["name"].as<std::string>();
    item["category"] = row["category"].as<std::string>();
    item["min_stock"] = row["min_stock"].as<int>();
    item["total"] = row["total"].as<int>();
    item["available"] = row["available"].as<int>();
    item["issued"] = row["issued"].as<int>();
    item["maintenance"] = row["maintenance"].as<int>();
    item["borrow_count"] = row["borrow_count"].as<int>();
    item["image"] = row["image_data"].isNull() ? "" : row["image_data"].as<std::string>();
    return item;
}

const std::string inventorySql =
    "SELECT e.id,e.name,e.category,e.min_stock,e.image_data,COUNT(u.id) AS total,"
    "COALESCE(SUM(u.status='AVAILABLE'),0) AS available,"
    "COALESCE(SUM(u.status='ISSUED'),0) AS issued,"
    "COALESCE(SUM(u.status='MAINTENANCE'),0) AS maintenance,"
    "(SELECT COUNT(*) FROM loans l JOIN units lu ON lu.id=l.unit_id WHERE lu.equipment_id=e.id) AS borrow_count "
    "FROM equipment e LEFT JOIN units u ON u.equipment_id=e.id ";

bool requireUser(const HttpRequestPtr &request, Callback &callback, Json::Value &user) {
    try { user = currentUser(request); return true; }
    catch (const std::runtime_error &e) { callback(error(k401Unauthorized, e.what())); }
    catch (...) { callback(error(k500InternalServerError, "Unable to verify account")); }
    return false;
}

bool requireAdmin(const HttpRequestPtr &request, Callback &callback, Json::Value &user) {
    if (!requireUser(request, callback, user)) return false;
    if (!admin(user)) {
        callback(error(k403Forbidden, "Administrator access required"));
        return false;
    }
    return true;
}

std::string value(const Json::Value &body, const char *key) {
    return body.isMember(key) && body[key].isString() ? body[key].asString() : "";
}

void outbox(const std::shared_ptr<orm::DbClient> &client,
            const std::string &type,
            const Json::Value &data) {
    Json::Value event;
    event["type"] = type;
    event["data"] = data;
    Json::StreamWriterBuilder writer;
    client->execSqlSync(
        "INSERT INTO outbox_events(event_type,payload,created_at) VALUES(?,?,UTC_TIMESTAMP(6))",
        type, Json::writeString(writer, event));
}

void commitTx(std::shared_ptr<orm::Transaction> &tx) {
    auto done = std::make_shared<std::promise<bool>>();
    auto result = done->get_future();
    tx->setCommitCallback([done](bool ok) { done->set_value(ok); });
    tx.reset();
    if (result.wait_for(std::chrono::seconds(10)) != std::future_status::ready || !result.get())
        throw std::runtime_error("Inventory transaction could not be committed");
}
}

void registerInventoryRoutes() {
    using namespace drogon;
    app().registerHandler(
        "/equipment",
        [](const HttpRequestPtr &request, Callback &&callback) {
            Json::Value user;
            if (!requireUser(request, callback, user)) return;
            try {
                const auto rows = app().getDbClient()->execSqlSync(
                    inventorySql + "GROUP BY e.id ORDER BY e.name");
                Json::Value result(Json::arrayValue);
                for (const auto &row : rows) result.append(asInventory(row));
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to load inventory")); }
        },
        {Get});

    app().registerHandler(
        "/units/{1}",
        [](const HttpRequestPtr &request, Callback &&callback, const std::string &barcode) {
            Json::Value user;
            if (!requireUser(request, callback, user)) return;
            try {
                const auto rows = app().getDbClient()->execSqlSync(
                    "SELECT u.id AS unit_id,u.serial,u.status,e.id AS equipment_id,e.name AS equipment_name,e.category "
                    "FROM units u JOIN equipment e ON e.id=u.equipment_id WHERE u.serial=?", barcode);
                if (rows.empty()) { callback(error(k404NotFound, "Scanned barcode was not found")); return; }
                Json::Value result;
                result["unit_id"] = rows[0]["unit_id"].as<std::string>();
                result["serial"] = rows[0]["serial"].as<std::string>();
                result["status"] = rows[0]["status"].as<std::string>();
                result["equipment_id"] = rows[0]["equipment_id"].as<std::string>();
                result["equipment_name"] = rows[0]["equipment_name"].as<std::string>();
                result["category"] = rows[0]["category"].as<std::string>();
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to look up item")); }
        },
        {Get});

    app().registerHandler(
        "/equipment/{1}",
        [](const HttpRequestPtr &request, Callback &&callback, const std::string &id) {
            Json::Value user;
            if (!requireUser(request, callback, user)) return;
            try {
                auto db = app().getDbClient();
                const auto rows = db->execSqlSync(
                    inventorySql + "WHERE e.id=? GROUP BY e.id", id);
                if (rows.empty()) { callback(error(k404NotFound, "Product not found")); return; }
                auto result = asInventory(rows[0]);
                const auto units = db->execSqlSync(
                    "SELECT id,serial,status FROM units WHERE equipment_id=? ORDER BY serial", id);
                Json::Value unitArray(Json::arrayValue);
                for (const auto &row : units) {
                    Json::Value unit;
                    unit["id"] = row["id"].as<std::string>();
                    unit["serial"] = row["serial"].as<std::string>();
                    unit["status"] = row["status"].as<std::string>();
                    unitArray.append(unit);
                }
                result["units"] = unitArray;
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to load product")); }
        },
        {Get});

    app().registerHandler(
        "/equipment/{1}/photo",
        [](const HttpRequestPtr &request, Callback &&callback, const std::string &id) {
            Json::Value user;
            if (!requireAdmin(request, callback, user)) return;
            const auto body = request->getJsonObject();
            const auto image = body ? value(*body, "image") : "";
            if (image.size() > 1400000 ||
                (!image.empty() && !std::regex_match(image, std::regex(R"([A-Za-z0-9+/]+={0,2})")))) {
                callback(error(k422UnprocessableEntity, "Choose an image smaller than 1 MB")); return;
            }
            try {
                auto db = app().getDbClient();
                db->execSqlSync("UPDATE equipment SET image_data=? WHERE id=?", image, id);
                Json::Value result;
                result["saved"] = true;
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to save product photo")); }
        }, {Patch});

    app().registerHandler(
        "/equipment",
        [](const HttpRequestPtr &request, Callback &&callback) {
            Json::Value user;
            if (!requireAdmin(request, callback, user)) return;
            const auto body = request->getJsonObject();
            if (!body) { callback(error(k400BadRequest, "Invalid JSON body")); return; }
            const auto id = value(*body, "id"), name = value(*body, "name"), category = value(*body, "category");
            const int minStock = body->isMember("min_stock") && (*body)["min_stock"].isInt()
                                     ? (*body)["min_stock"].asInt() : 0;
            if (id.empty() || name.empty() || category.empty() || minStock < 0) {
                callback(error(k422UnprocessableEntity, "Product ID, name, category, and valid minimum stock are required")); return;
            }
            try {
                auto tx = app().getDbClient()->newTransaction();
                tx->execSqlSync(
                    "INSERT INTO equipment(id,name,category,min_stock) VALUES(?,?,?,?)",
                    id, name, category, minStock);
                auto rows = tx->execSqlSync(
                    inventorySql + "WHERE e.id=? GROUP BY e.id", id);
                auto result = asInventory(rows[0]);
                outbox(tx, "inventory", result);
                commitTx(tx);
                callback(json(result, k201Created));
            } catch (...) { callback(error(k409Conflict, "Unable to create product; check that the equipment ID is unique")); }
        },
        {Post});

    app().registerHandler(
        "/equipment/{1}/units",
        [](const HttpRequestPtr &request, Callback &&callback, const std::string &equipmentId) {
            Json::Value user;
            if (!requireAdmin(request, callback, user)) return;
            const auto body = request->getJsonObject();
            const auto serial = body ? value(*body, "serial") : "";
            if (serial.empty()) { callback(error(k422UnprocessableEntity, "Serial/barcode cannot be blank")); return; }
            try {
                auto db = app().getDbClient();
                auto tx = db->newTransaction();
                const auto exists = tx->execSqlSync("SELECT id FROM equipment WHERE id=? FOR UPDATE", equipmentId);
                if (exists.empty()) { callback(error(k404NotFound, "Product not found")); return; }
                const auto unitId = utils::getUuid();
                const auto transactionId = utils::getUuid();
                const auto key = "unit-receive-" + unitId;
                tx->execSqlSync("INSERT INTO units(id,equipment_id,serial,status) VALUES(?,?,?,'AVAILABLE')",
                                unitId, equipmentId, serial);
                tx->execSqlSync(
                    "INSERT INTO transactions(id,equipment_id,unit_id,loan_id,type,quantity,created_at,actor_id,idempotency_key) "
                    "VALUES(?,?,?,NULL,'RECEIVE',1,UTC_TIMESTAMP(6),?,?)",
                    transactionId, equipmentId, unitId, user["id"].asString(), key);
                Json::Value out;
                out["id"] = unitId;
                out["equipment_id"] = equipmentId;
                out["serial"] = serial;
                out["status"] = "AVAILABLE";
                Json::Value event;
                event["equipment_id"] = equipmentId;
                event["type"] = "RECEIVE";
                event["quantity"] = 1;
                event["serial"] = serial;
                event["unit_id"] = unitId;
                outbox(tx, "transaction", event);
                commitTx(tx);
                callback(json(out, k201Created));
            } catch (const drogon::orm::DrogonDbException &) {
                callback(error(k409Conflict, "This serial/barcode is already registered"));
            } catch (...) { callback(error(k500InternalServerError, "Unable to register item")); }
        },
        {Post});

    app().registerHandler(
        "/equipment/{1}",
        [](const HttpRequestPtr &request, Callback &&callback, const std::string &id) {
            Json::Value user;
            if (!requireAdmin(request, callback, user)) return;
            const auto body = request->getJsonObject();
            if (!body) { callback(error(k400BadRequest, "Invalid JSON body")); return; }
            const auto name = value(*body, "name"), category = value(*body, "category");
            const int minStock = body->isMember("min_stock") && (*body)["min_stock"].isInt()
                                     ? (*body)["min_stock"].asInt() : 0;
            if (name.empty() || category.empty() || minStock < 0) {
                callback(error(k422UnprocessableEntity, "Product name, category, and minimum stock are required")); return;
            }
            try {
                auto db = app().getDbClient();
                auto tx = db->newTransaction();
                const auto changed = tx->execSqlSync(
                    "UPDATE equipment SET name=?,category=?,min_stock=? WHERE id=?",
                    name, category, minStock, id);
                if (changed.affectedRows() == 0) {
                    const auto found = tx->execSqlSync("SELECT id FROM equipment WHERE id=?", id);
                    if (found.empty()) { callback(error(k404NotFound, "Product not found")); return; }
                }
                const auto rows = tx->execSqlSync(inventorySql + "WHERE e.id=? GROUP BY e.id", id);
                auto result = asInventory(rows[0]);
                outbox(tx, "inventory", result);
                commitTx(tx);
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to update product")); }
        },
        {Patch});

    app().registerHandler(
        "/equipment/{1}",
        [](const HttpRequestPtr &request, Callback &&callback, const std::string &id) {
            Json::Value user;
            if (!requireAdmin(request, callback, user)) return;
            try {
                auto db = app().getDbClient();
                auto tx = db->newTransaction();
                const auto history = tx->execSqlSync("SELECT id FROM transactions WHERE equipment_id=? LIMIT 1 FOR UPDATE", id);
                if (!history.empty()) { callback(error(k409Conflict, "Products with transaction history cannot be deleted; change units to maintenance instead")); return; }
                tx->execSqlSync("DELETE FROM units WHERE equipment_id=?", id);
                const auto removed = tx->execSqlSync("DELETE FROM equipment WHERE id=?", id);
                if (removed.affectedRows() == 0) { callback(error(k404NotFound, "Product not found")); return; }
                Json::Value result;
                result["deleted"] = id;
                outbox(tx, "inventory", result);
                commitTx(tx);
                callback(json(result));
            } catch (...) { callback(error(k409Conflict, "Unable to delete product")); }
        },
        {Delete});

    app().registerHandler(
        "/units/{1}/status",
        [](const HttpRequestPtr &request, Callback &&callback, const std::string &unitId) {
            Json::Value user;
            if (!requireAdmin(request, callback, user)) return;
            const auto body = request->getJsonObject();
            const auto status = body ? value(*body, "status") : "";
            if (status != "AVAILABLE" && status != "MAINTENANCE") {
                callback(error(k422UnprocessableEntity, "Set a unit to AVAILABLE or MAINTENANCE")); return;
            }
            try {
                auto db = app().getDbClient();
                auto tx = db->newTransaction();
                const auto rows = tx->execSqlSync("SELECT status FROM units WHERE id=? FOR UPDATE", unitId);
                if (rows.empty()) { callback(error(k404NotFound, "Unit not found")); return; }
                if (rows[0]["status"].as<std::string>() == "ISSUED") {
                    callback(error(k409Conflict, "An issued unit can only be made available by completing its return")); return;
                }
                tx->execSqlSync("UPDATE units SET status=? WHERE id=?", status, unitId);
                Json::Value result;
                result["id"] = unitId;
                result["status"] = status;
                outbox(tx, "inventory", result);
                commitTx(tx);
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to update item status")); }
        },
        {Patch});

    app().registerHandler(
        "/transactions",
        [](const HttpRequestPtr &request, Callback &&callback) {
            Json::Value user;
            if (!requireAdmin(request, callback, user)) return;
            const auto equipmentId = request->getParameter("equipment_id");
            const auto type = request->getParameter("type");
            std::string sql =
                "SELECT t.id,t.equipment_id,t.unit_id,t.loan_id,t.type,t.quantity,"
                "DATE_FORMAT(t.created_at,'%Y-%m-%dT%H:%i:%s.%fZ') AS created_at,"
                "t.actor_id,t.idempotency_key,e.name AS equipment_name,u.serial,usr.name AS actor_name "
                "FROM transactions t JOIN equipment e ON e.id=t.equipment_id "
                "LEFT JOIN units u ON u.id=t.unit_id JOIN users usr ON usr.id=t.actor_id WHERE 1=1";
            if (!equipmentId.empty()) sql += " AND t.equipment_id=?";
            if (!type.empty()) sql += " AND t.type=?";
            sql += " ORDER BY t.created_at DESC";
            try {
                auto db = app().getDbClient();
                const auto rows = !equipmentId.empty() && !type.empty()
                    ? db->execSqlSync(sql, equipmentId, type)
                    : !equipmentId.empty()
                        ? db->execSqlSync(sql, equipmentId)
                        : !type.empty()
                            ? db->execSqlSync(sql, type)
                            : db->execSqlSync(sql);
                Json::Value result(Json::arrayValue);
                for (const auto &row : rows) {
                    Json::Value tx;
                    tx["id"] = row["id"].as<std::string>();
                    tx["equipment_id"] = row["equipment_id"].as<std::string>();
                    tx["unit_id"] = row["unit_id"].isNull() ? Json::Value() : Json::Value(row["unit_id"].as<std::string>());
                    tx["loan_id"] = row["loan_id"].isNull() ? Json::Value() : Json::Value(row["loan_id"].as<std::string>());
                    tx["type"] = row["type"].as<std::string>();
                    tx["quantity"] = row["quantity"].as<int>();
                    tx["created_at"] = row["created_at"].as<std::string>();
                    tx["actor_id"] = row["actor_id"].as<std::string>();
                    tx["idempotency_key"] = row["idempotency_key"].as<std::string>();
                    tx["equipment_name"] = row["equipment_name"].as<std::string>();
                    tx["serial"] = row["serial"].isNull() ? Json::Value() : Json::Value(row["serial"].as<std::string>());
                    tx["actor_name"] = row["actor_name"].as<std::string>();
                    result.append(tx);
                }
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to load transaction history")); }
        },
        {Get});

    app().registerHandler(
        "/reports/low-stock",
        [](const HttpRequestPtr &request, Callback &&callback) {
            Json::Value user;
            if (!requireAdmin(request, callback, user)) return;
            try {
                const auto rows = app().getDbClient()->execSqlSync(
                    inventorySql + "GROUP BY e.id HAVING available<=e.min_stock ORDER BY e.name");
                Json::Value result(Json::arrayValue);
                for (const auto &row : rows) result.append(asInventory(row));
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to load low-stock report")); }
        },
        {Get});
}
}
