#include <drogon/drogon.h>
#include "api.hpp"
#include <cstdlib>
#include <iostream>
#include <string>

namespace {
std::string env(const char *name, const char *fallback) {
    const auto *value = std::getenv(name);
    return value && *value ? value : fallback;
}
bool allowedWebOrigin(const std::string &origin) {
    return origin == "https://ngiga-avelino-demo.garquejether681.workers.dev" ||
           origin == "http://localhost:5173" || origin == "http://127.0.0.1:5173";
}
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    drogon::orm::MysqlConfig mysql{};
    mysql.host = env("MYSQL_HOST", "127.0.0.1");
    mysql.port = static_cast<unsigned short>(std::stoi(env("MYSQL_PORT", "3306")));
    mysql.databaseName = env("MYSQL_DATABASE", "stockroom");
    mysql.username = env("MYSQL_USER", "stockroom_app");
    mysql.password = env("MYSQL_PASSWORD", "");
    mysql.connectionNumber = 12;
    mysql.name = "default";
    mysql.isFast = false;
    mysql.characterSet = "utf8mb4";
    mysql.timeout = 10;
    drogon::app()
        .addDbClient(mysql)
        .setThreadNum(4)
        .addListener("0.0.0.0",
                     static_cast<unsigned short>(std::stoi(env("PORT", "8000"))));
    drogon::app().registerSyncAdvice([](const drogon::HttpRequestPtr &request) {
        if (request->method() != drogon::Options ||
            !allowedWebOrigin(request->getHeader("origin"))) return drogon::HttpResponsePtr{};
        auto response = drogon::HttpResponse::newHttpResponse();
        response->setStatusCode(drogon::k204NoContent);
        response->addHeader("Access-Control-Allow-Origin", request->getHeader("origin"));
        response->addHeader("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS");
        response->addHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
        response->addHeader("Access-Control-Max-Age", "600");
        response->addHeader("Vary", "Origin");
        return response;
    });
    drogon::app().registerPreSendingAdvice([](const drogon::HttpRequestPtr &request,
                                               const drogon::HttpResponsePtr &response) {
        const auto origin = request->getHeader("origin");
        if (allowedWebOrigin(origin)) {
            response->addHeader("Access-Control-Allow-Origin", origin);
            response->addHeader("Vary", "Origin");
        }
    });
    stockroom::registerAuthRoutes();
    stockroom::registerInventoryRoutes();
    stockroom::registerLoanRoutes();
    try {
        stockroom::startOutboxPump();
    } catch (const std::exception &e) {
        std::cerr << "Failed to initialize database event pump: " << e.what() << std::endl;
        return 1;
    }
    drogon::app().registerHandler(
        "/health",
        [](const drogon::HttpRequestPtr &,
           std::function<void(const drogon::HttpResponsePtr &)> &&callback) {
            Json::Value body;
            body["service"] = "stockroom-cpp-api";
            try {
                const auto db = drogon::app().getDbClient();
                const auto result = db->execSqlSync("SELECT 1 AS ready");
                body["status"] = result.size() == 1 ? "ok" : "degraded";
                body["database"] = "mysql";
                callback(drogon::HttpResponse::newHttpJsonResponse(body));
            } catch (const std::exception &) {
                body["status"] = "degraded";
                body["error"] = "database unavailable";
                auto response = drogon::HttpResponse::newHttpJsonResponse(body);
                response->setStatusCode(drogon::k503ServiceUnavailable);
                callback(response);
            }
        },
        {drogon::Get});
    drogon::app().run();
}
