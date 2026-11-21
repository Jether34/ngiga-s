#pragma once

#include <drogon/drogon.h>

namespace stockroom {
using Callback = std::function<void(const drogon::HttpResponsePtr &)>;
drogon::HttpResponsePtr json(const Json::Value &body,
                             drogon::HttpStatusCode status = drogon::k200OK);
drogon::HttpResponsePtr error(drogon::HttpStatusCode status,
                              const std::string &message);
Json::Value currentUser(const drogon::HttpRequestPtr &request);
void registerAuthRoutes();
void registerInventoryRoutes();
void registerLoanRoutes();
void startOutboxPump();
}
