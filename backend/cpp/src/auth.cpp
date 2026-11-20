#include "api.hpp"

#include "../vendor/bcrypt/include/bcrypt/bcrypt.h"
#include <jwt-cpp/jwt.h>
#include <jwt-cpp/traits/nlohmann-json/defaults.h>
#include <cstdlib>
#include <cctype>
#include <regex>
#include <algorithm>

namespace stockroom {
namespace {
std::string secret() {
    const auto *value = std::getenv("SECRET_KEY");
    if (!value || std::string(value).size() < 32)
        throw std::runtime_error("SECRET_KEY must contain at least 32 characters");
    return value;
}

std::string field(const Json::Value &body, const char *name) {
    return body.isMember(name) && body[name].isString() ? body[name].asString() : "";
}

std::string normalizedPhone(const std::string &value) {
    std::string result;
    for (const unsigned char ch : value) {
        if (std::isdigit(ch) || (ch == '+' && result.empty())) result += static_cast<char>(ch);
    }
    return result;
}
}

drogon::HttpResponsePtr json(const Json::Value &body, drogon::HttpStatusCode status) {
    auto response = drogon::HttpResponse::newHttpJsonResponse(body);
    response->setStatusCode(status);
    return response;
}

drogon::HttpResponsePtr error(drogon::HttpStatusCode status,
                              const std::string &message) {
    Json::Value body;
    body["detail"] = message;
    return json(body, status);
}

Json::Value currentUser(const drogon::HttpRequestPtr &request) {
    const auto auth = request->getHeader("authorization");
    if (auth.rfind("Bearer ", 0) != 0)
        throw std::runtime_error("Sign in required");
    try {
        const auto token = jwt::decode(auth.substr(7));
        jwt::verify()
            .allow_algorithm(jwt::algorithm::hs256{secret()})
            .with_issuer("stockroom")
            .verify(token);
        auto db = drogon::app().getDbClient();
        const auto rows = db->execSqlSync(
            "SELECT id,email,name,account_id,role,phone,year_level,program,section,home_address,terms_accepted_at FROM users WHERE id=?",
            token.get_subject());
        if (rows.empty()) throw std::runtime_error("Session expired");
        Json::Value user;
        user["id"] = rows[0]["id"].as<std::string>();
        user["email"] = rows[0]["email"].as<std::string>();
        user["name"] = rows[0]["name"].as<std::string>();
        user["account_id"] = rows[0]["account_id"].as<std::string>();
        user["role"] = rows[0]["role"].as<std::string>();
        for (const auto *key : {"phone", "year_level", "program", "section", "home_address"})
            user[key] = rows[0][key].isNull() ? "" : rows[0][key].as<std::string>();
        user["terms_accepted_at"] = rows[0]["terms_accepted_at"].isNull() ? "" : rows[0]["terms_accepted_at"].as<std::string>();
        return user;
    } catch (const std::runtime_error &) {
        throw;
    } catch (...) {
        throw std::runtime_error("Session expired");
    }
}

void registerAuthRoutes() {
    using namespace drogon;
    app().registerHandler(
        "/auth/signup",
        [](const HttpRequestPtr &request, Callback &&callback) {
            const auto body = request->getJsonObject();
            if (!body) { callback(error(k400BadRequest, "Invalid JSON body")); return; }
            auto name = field(*body, "name");
            auto email = field(*body, "email");
            auto phone = field(*body, "phone");
            auto yearLevel = field(*body, "year_level");
            auto program = field(*body, "program");
            auto section = field(*body, "section");
            auto studentId = field(*body, "student_id");
            auto address = field(*body, "home_address");
            const auto password = field(*body, "password");
            const bool termsAccepted = body->isMember("agree_terms") &&
                                       (*body)["agree_terms"].isBool() &&
                                       (*body)["agree_terms"].asBool();
            name.erase(0, name.find_first_not_of(" \t\r\n"));
            name.erase(name.find_last_not_of(" \t\r\n") + 1);
            email.erase(0, email.find_first_not_of(" \t\r\n"));
            email.erase(email.find_last_not_of(" \t\r\n") + 1);
            phone.erase(0, phone.find_first_not_of(" \t\r\n"));
            phone.erase(phone.find_last_not_of(" \t\r\n") + 1);
            yearLevel.erase(0, yearLevel.find_first_not_of(" \t\r\n"));
            yearLevel.erase(yearLevel.find_last_not_of(" \t\r\n") + 1);
            program.erase(0, program.find_first_not_of(" \t\r\n"));
            program.erase(program.find_last_not_of(" \t\r\n") + 1);
            address.erase(0, address.find_first_not_of(" \t\r\n"));
            address.erase(address.find_last_not_of(" \t\r\n") + 1);
            section.erase(0, section.find_first_not_of(" \t\r\n"));
            section.erase(section.find_last_not_of(" \t\r\n") + 1);
            studentId.erase(0, studentId.find_first_not_of(" \t\r\n"));
            studentId.erase(studentId.find_last_not_of(" \t\r\n") + 1);
            std::transform(email.begin(), email.end(), email.begin(),
                           [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            const bool phoneCharactersValid = std::regex_match(
                phone, std::regex(R"(\+?[0-9() -]{7,30})"));
            phone = normalizedPhone(phone);
            const bool validYear = yearLevel == "1st Year" || yearLevel == "2nd Year" ||
                                   yearLevel == "3rd Year" || yearLevel == "4th Year";
            if (name.size() < 2 || name.size() > 100 || password.size() < 12 || password.size() > 72 ||
                !std::regex_match(email, std::regex(R"([^@\s]+@[^@\s]+\.[^@\s]+)")) ||
                !phoneCharactersValid ||
                !std::regex_match(phone, std::regex(R"(\+?[0-9]{7,20})")) ||
                !validYear || program.size() < 2 || program.size() > 120 ||
                address.size() < 5 || address.size() > 240 || section.size() > 32 ||
                (!studentId.empty() && !std::regex_match(studentId, std::regex(R"([A-Za-z0-9-]{3,32})"))) ||
                !termsAccepted) {
                callback(error(k422UnprocessableEntity, "Complete all required fields, accept the terms, and use a password of at least 12 characters")); return;
            }
            try {
                const auto uid = drogon::utils::getUuid();
                const auto accountId = studentId.empty() ? "STU-" + uid.substr(0, 8) : studentId;
                const auto hash = bcrypt::generateHash(password, 12);
                auto db = app().getDbClient();
                db->execSqlSync(
                    "INSERT INTO users(id,email,password_hash,name,account_id,phone,year_level,program,section,home_address,terms_accepted_at,role) VALUES(?,?,?,?,?,?,?,?,?,?,UTC_TIMESTAMP(6),'STUDENT')",
                    uid, email, hash, name, accountId, phone, yearLevel, program, section, address);
                Json::Value result;
                result["message"] = "Student account created. Sign in to continue.";
                result["account_id"] = accountId;
                result["role"] = "STUDENT";
                callback(json(result, k201Created));
            } catch (const drogon::orm::DrogonDbException &) {
                callback(error(k409Conflict, "That email or phone number is already registered"));
            } catch (...) {
                callback(error(k500InternalServerError, "Unable to create account"));
            }
        },
        {Post});

    app().registerHandler(
        "/auth/login",
        [](const HttpRequestPtr &request, Callback &&callback) {
            const auto body = request->getJsonObject();
            if (!body) { callback(error(k400BadRequest, "Invalid JSON body")); return; }
            const auto password = field(*body, "password");
            try {
                auto db = app().getDbClient();
                const auto loginType = field(*body, "login_type");
                const auto phone = field(*body, "phone");
                const auto email = field(*body, "email");
                const bool phoneLogin = loginType == "phone" || (!phone.empty() && email.empty());
                if (phoneLogin) {
                    const auto normalized = normalizedPhone(phone);
                    if (!std::regex_match(phone, std::regex(R"(\+?[0-9() -]{7,30})")) ||
                        !std::regex_match(normalized, std::regex(R"(\+?[0-9]{7,20})"))) {
                        callback(error(k422UnprocessableEntity, "Enter a valid phone number")); return;
                    }
                } else if (email.empty()) {
                    callback(error(k422UnprocessableEntity, "Enter your email or phone number")); return;
                }
                const auto rows = phoneLogin
                    ? db->execSqlSync(
                        "SELECT id,email,password_hash,name,account_id,role FROM users WHERE REPLACE(REPLACE(REPLACE(REPLACE(phone,' ',''),'-',''),'(',''),')','')=?",
                        normalizedPhone(phone))
                    : db->execSqlSync(
                        "SELECT id,email,password_hash,name,account_id,role FROM users WHERE lower(email)=lower(?)",
                        email);
                if (rows.empty() || !bcrypt::validatePassword(
                        password, rows[0]["password_hash"].as<std::string>())) {
                    callback(error(k401Unauthorized, "Email, phone, or password is incorrect")); return;
                }
                const auto uid = rows[0]["id"].as<std::string>();
                const auto token = jwt::create()
                    .set_issuer("stockroom")
                    .set_subject(uid)
                    .set_issued_at(std::chrono::system_clock::now())
                    .set_expires_at(std::chrono::system_clock::now() + std::chrono::hours(12))
                    .sign(jwt::algorithm::hs256{secret()});
                Json::Value user;
                user["id"] = uid;
                user["email"] = rows[0]["email"].as<std::string>();
                user["name"] = rows[0]["name"].as<std::string>();
                user["account_id"] = rows[0]["account_id"].as<std::string>();
                user["role"] = rows[0]["role"].as<std::string>();
                Json::Value result;
                result["token"] = token;
                result["user"] = user;
                callback(json(result));
            } catch (...) {
                callback(error(k500InternalServerError, "Unable to sign in"));
            }
        },
        {Post});

    app().registerHandler(
        "/me",
        [](const HttpRequestPtr &request, Callback &&callback) {
            try { callback(json(currentUser(request))); }
            catch (const std::runtime_error &e) { callback(error(k401Unauthorized, e.what())); }
            catch (...) { callback(error(k500InternalServerError, "Unable to read account")); }
        },
        {Get});

    app().registerHandler(
        "/me",
        [](const HttpRequestPtr &request, Callback &&callback) {
            Json::Value user;
            try { user = currentUser(request); }
            catch (const std::runtime_error &e) { callback(error(k401Unauthorized, e.what())); return; }
            const auto body = request->getJsonObject();
            if (!body) { callback(error(k400BadRequest, "Invalid JSON body")); return; }
            auto name = field(*body, "name"), phone = field(*body, "phone");
            auto section = field(*body, "section"), address = field(*body, "home_address");
            auto email = field(*body, "email");
            const auto accountId = user["account_id"].asString();
            const auto year = user["year_level"].asString();
            const auto program = user["program"].asString();
            if (body->isMember("program") && field(*body, "program") != program) {
                callback(error(k403Forbidden, "Program cannot be changed")); return;
            }
            if (body->isMember("student_id") && field(*body, "student_id") != accountId) {
                callback(error(k403Forbidden, "Student ID cannot be changed")); return;
            }
            if (body->isMember("year_level") && field(*body, "year_level") != year) {
                callback(error(k403Forbidden, "Year level cannot be changed")); return;
            }
            phone = normalizedPhone(phone);
            if (name.size() < 2 || name.size() > 100 || section.empty() || section.size() > 32 ||
                address.size() < 5 || address.size() > 240 ||
                !std::regex_match(phone, std::regex(R"(\+?[0-9]{7,20})")) ||
                !std::regex_match(email, std::regex(R"([^@\s]+@[^@\s]+\.[^@\s]+)")) ||
                !std::regex_match(accountId, std::regex(R"([A-Za-z0-9-]{3,32})")) ||
                !(year == "1st Year" || year == "2nd Year" || year == "3rd Year" || year == "4th Year") ||
                program.size() < 2 || program.size() > 120) {
                callback(error(k422UnprocessableEntity, "Enter valid profile details")); return;
            }
            try {
                app().getDbClient()->execSqlSync(
                    "UPDATE users SET name=?,email=?,phone=?,section=?,home_address=? WHERE id=? AND role='STUDENT'",
                    name, email, phone, section, address, user["id"].asString());
                callback(json(currentUser(request)));
            } catch (const drogon::orm::DrogonDbException &) {
                callback(error(k409Conflict, "Email, phone, or student ID is already in use"));
            } catch (...) { callback(error(k500InternalServerError, "Unable to update profile")); }
        },
        {Patch});

    app().registerHandler(
        "/me/avatar",
        [](const HttpRequestPtr &request, Callback &&callback) {
            Json::Value user;
            try { user = currentUser(request); }
            catch (const std::runtime_error &e) { callback(error(k401Unauthorized, e.what())); return; }
            try {
                const auto rows = app().getDbClient()->execSqlSync(
                    "SELECT avatar_data FROM users WHERE id=?", user["id"].asString());
                Json::Value result;
                result["image"] = rows.empty() || rows[0]["avatar_data"].isNull()
                    ? "" : rows[0]["avatar_data"].as<std::string>();
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to load profile photo")); }
        },
        {Get});

    app().registerHandler(
        "/me/avatar",
        [](const HttpRequestPtr &request, Callback &&callback) {
            Json::Value user;
            try { user = currentUser(request); }
            catch (const std::runtime_error &e) { callback(error(k401Unauthorized, e.what())); return; }
            const auto body = request->getJsonObject();
            if (!body || !(*body)["image"].isString()) {
                callback(error(k400BadRequest, "Invalid image")); return;
            }
            const auto image = (*body)["image"].asString();
            if (image.size() > 700000 ||
                (!image.empty() && !std::regex_match(image, std::regex(R"([A-Za-z0-9+/]+={0,2})")))) {
                callback(error(k422UnprocessableEntity, "Choose a smaller JPEG profile photo")); return;
            }
            try {
                app().getDbClient()->execSqlSync(
                    "UPDATE users SET avatar_data=? WHERE id=?", image, user["id"].asString());
                Json::Value result;
                result["saved"] = true;
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to save profile photo")); }
        },
        {Patch});

    app().registerHandler(
        "/leaderboard",
        [](const HttpRequestPtr &request, Callback &&callback) {
            try { currentUser(request); }
            catch (const std::runtime_error &e) { callback(error(k401Unauthorized, e.what())); return; }
            try {
                const auto rows = app().getDbClient()->execSqlSync(
                    "SELECT u.name,u.program,u.year_level,u.section,COUNT(l.id) AS borrow_count FROM users u "
                    "JOIN loans l ON l.user_id=u.id WHERE u.role='STUDENT' "
                    "GROUP BY u.id,u.name,u.program,u.year_level,u.section ORDER BY borrow_count DESC,u.name ASC LIMIT 20");
                Json::Value result(Json::arrayValue);
                for (const auto &row : rows) {
                    Json::Value item;
                    item["name"] = row["name"].as<std::string>();
                    for (const auto *key : {"program", "year_level", "section"})
                        item[key] = row[key].isNull() ? "" : row[key].as<std::string>();
                    item["borrow_count"] = row["borrow_count"].as<int>();
                    result.append(item);
                }
                callback(json(result));
            } catch (...) { callback(error(k500InternalServerError, "Unable to load leaderboard")); }
        },
        {Get});
}
}
