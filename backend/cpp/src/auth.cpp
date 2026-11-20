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
            "SELECT id,email,name,account_id,role FROM users WHERE id=?",
            token.get_subject());
        if (rows.empty()) throw std::runtime_error("Session expired");
        Json::Value user;
        user["id"] = rows[0]["id"].as<std::string>();
        user["email"] = rows[0]["email"].as<std::string>();
        user["name"] = rows[0]["name"].as<std::string>();
        user["account_id"] = rows[0]["account_id"].as<std::string>();
        user["role"] = rows[0]["role"].as<std::string>();
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
            std::transform(email.begin(), email.end(), email.begin(),
                           [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            const bool validYear = yearLevel == "1st Year" || yearLevel == "2nd Year" ||
                                   yearLevel == "3rd Year" || yearLevel == "4th Year" ||
                                   yearLevel == "5th Year" || yearLevel == "Graduate";
            if (name.size() < 2 || name.size() > 100 || password.size() < 12 || password.size() > 72 ||
                !std::regex_match(email, std::regex(R"([^@\s]+@[^@\s]+\.[^@\s]+)")) ||
                !std::regex_match(phone, std::regex(R"(\+?[0-9][0-9() -]{6,20})")) ||
                !validYear || program.size() < 2 || program.size() > 120 ||
                address.size() < 5 || address.size() > 240 || !termsAccepted) {
                callback(error(k422UnprocessableEntity, "Complete all required fields, accept the terms, and use a password of at least 12 characters")); return;
            }
            try {
                const auto uid = drogon::utils::getUuid();
                const auto accountId = "STU-" + uid.substr(0, 8);
                const auto hash = bcrypt::generateHash(password, 12);
                auto db = app().getDbClient();
                db->execSqlSync(
                    "INSERT INTO users(id,email,password_hash,name,account_id,phone,year_level,program,home_address,terms_accepted_at,role) VALUES(?,?,?,?,?,?,?,?,?,UTC_TIMESTAMP(6),'STUDENT')",
                    uid, email, hash, name, accountId, phone, yearLevel, program, address);
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
            auto email = field(*body, "email");
            const auto password = field(*body, "password");
            try {
                auto db = app().getDbClient();
                drogon::orm::Result rows;
                const auto loginType = field(*body, "login_type");
                if (loginType == "phone") {
                    rows = db->execSqlSync(
                        "SELECT id,email,password_hash,name,account_id,role FROM users WHERE phone=?",
                        field(*body, "phone"));
                } else {
                    rows = db->execSqlSync(
                        "SELECT id,email,password_hash,name,account_id,role FROM users WHERE lower(email)=lower(?)",
                        field(*body, "email"));
                }
                if (rows.empty() || !bcrypt::validatePassword(
                        password, rows[0]["password_hash"].as<std::string>())) {
                    callback(error(k401Unauthorized, "Email or password is incorrect")); return;
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
}
}
