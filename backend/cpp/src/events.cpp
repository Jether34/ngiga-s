#include "api.hpp"

#include "../vendor/bcrypt/include/bcrypt/bcrypt.h"
#include <drogon/WebSocketController.h>
#include <jwt-cpp/jwt.h>
#include <jwt-cpp/traits/nlohmann-json/defaults.h>
#include <algorithm>
#include <atomic>
#include <cstdlib>
#include <mutex>
#include <thread>
#include <utility>
#include <vector>

namespace stockroom {
namespace {
using namespace drogon;
std::mutex socketMutex;
std::vector<WebSocketConnectionPtr> sockets;
std::atomic<unsigned long long> lastEvent{0};

std::string jwtSecret() {
    const auto *value = std::getenv("SECRET_KEY");
    if (!value || std::string(value).size() < 32) throw std::runtime_error("Invalid JWT key");
    return value;
}

class AdminEvents final : public WebSocketController<AdminEvents> {
  public:
    void handleNewMessage(const WebSocketConnectionPtr &,
                          std::string &&,
                          const WebSocketMessageType &) override {}
    void handleNewConnection(const HttpRequestPtr &request,
                             const WebSocketConnectionPtr &connection) override {
        try {
            const auto encoded = request->getParameter("token");
            const auto token = jwt::decode(encoded);
            jwt::verify().allow_algorithm(jwt::algorithm::hs256{jwtSecret()})
                .with_issuer("stockroom").verify(token);
            const auto users = app().getDbClient()->execSqlSync(
                "SELECT role FROM users WHERE id=?", token.get_subject());
            if (users.empty() || users[0]["role"].as<std::string>() != "ADMIN") {
                connection->shutdown(CloseCode::kProtocolError,
                                     "Administrator access required");
                return;
            }
            std::lock_guard<std::mutex> lock(socketMutex);
            sockets.push_back(connection);
        } catch (...) {
            connection->shutdown(CloseCode::kProtocolError,
                                 "Invalid administrator session");
        }
    }
    void handleConnectionClosed(const WebSocketConnectionPtr &connection) override {
        std::lock_guard<std::mutex> lock(socketMutex);
        sockets.erase(std::remove(sockets.begin(), sockets.end(), connection), sockets.end());
    }
    WS_PATH_LIST_BEGIN
    WS_PATH_ADD("/events", Get);
    WS_PATH_LIST_END
};

void publish(const std::string &payload) {
    std::vector<WebSocketConnectionPtr> clients;
    {
        std::lock_guard<std::mutex> lock(socketMutex);
        clients = sockets;
    }
    for (const auto &client : clients) {
        if (client && client->connected()) client->send(payload);
    }
}

}

void startOutboxPump() {
    app().registerBeginningAdvice([]() {
        auto db = app().getDbClient();
        const std::vector<std::pair<std::string, std::string>> profileColumns = {
            {"phone", "phone VARCHAR(32) NULL UNIQUE"},
            {"year_level", "year_level VARCHAR(24) NULL"},
            {"program", "program VARCHAR(120) NULL"},
            {"section", "section VARCHAR(32) NULL"},
            {"home_address", "home_address VARCHAR(240) NULL"},
            {"avatar_data", "avatar_data MEDIUMTEXT NULL"},
            {"terms_accepted_at", "terms_accepted_at DATETIME(6) NULL"},
            {"deleted_at", "deleted_at DATETIME(6) NULL"},
        };
        for (const auto &[name, definition] : profileColumns) {
            auto exists = [&]() {
                return db->execSqlSync(
                    "SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME=?",
                    name);
            };
            if (exists().empty()) {
                try {
                    db->execSqlSync("ALTER TABLE users ADD COLUMN " + definition);
                } catch (const orm::DrogonDbException &) {
                    // Another API replica may have applied this column migration.
                    if (exists().empty()) throw;
                }
            }
        }
        db->execSqlSync("CREATE TABLE IF NOT EXISTS notification_reads ("
            "user_id VARCHAR(36) NOT NULL,notification_id VARCHAR(64) NOT NULL,"
            "read_at DATETIME(6) NOT NULL,PRIMARY KEY(user_id,notification_id),"
            "CONSTRAINT fk_notification_reads_user FOREIGN KEY(user_id) REFERENCES users(id)) ENGINE=InnoDB");
        const auto admins = db->execSqlSync("SELECT id FROM users WHERE role='ADMIN' LIMIT 1");
        if (admins.empty()) {
            const auto *password = std::getenv("ADMIN_PASSWORD");
            const auto *email = std::getenv("ADMIN_EMAIL");
            if (!password || std::string(password).size() < 12 || !email || !*email)
                throw std::runtime_error("Set ADMIN_EMAIL and ADMIN_PASSWORD (12+ characters) to seed the administrator account");
            try {
                const auto *name = std::getenv("ADMIN_NAME");
                const auto *accountId = std::getenv("ADMIN_ID");
                db->execSqlSync(
                    "INSERT INTO users(id,email,password_hash,name,account_id,role) VALUES(?,?,?,?,?,'ADMIN')",
                    utils::getUuid(), email, bcrypt::generateHash(password, 12),
                    name ? name : "Laboratory Administrator",
                    accountId ? accountId : "ADMIN-001");
            } catch (const orm::DrogonDbException &) {
                // Another replica may seed the same configured administrator at the same time.
            }
        }
        const auto latest = db->execSqlSync(
            "SELECT COALESCE(MAX(id),0) AS latest FROM outbox_events");
        if (!latest.empty()) lastEvent.store(latest[0]["latest"].as<unsigned long long>());
        std::thread([db]() {
            while (true) {
                try {
                    const auto rows = db->execSqlSync(
                        "SELECT id,payload FROM outbox_events WHERE id>? ORDER BY id LIMIT 100",
                        lastEvent.load());
                    for (const auto &row : rows) {
                        lastEvent.store(row["id"].as<unsigned long long>());
                        publish(row["payload"].as<std::string>());
                    }
                } catch (const std::exception &e) {
                    LOG_ERROR << "Outbox polling failed: " << e.what();
                }
                std::this_thread::sleep_for(std::chrono::milliseconds(250));
            }
        }).detach();
    });
}
}
