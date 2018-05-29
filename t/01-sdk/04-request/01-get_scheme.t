use strict;
use warnings FATAL => 'all';
use Test::Nginx::Socket::Lua;
use File::Spec;

$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();
$ENV{TEST_NGINX_CERT_DIR} ||= File::Spec->catdir(server_root(), '..', 'certs');

plan tests => repeat_each() * (blocks() * 3);

run_tests();

__DATA__

=== TEST 1: request.get_scheme() returns http for plain text requests
--- config
    location = /t {
        access_by_lua_block {
            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            ngx.say("scheme: ", sdk.request.get_scheme())
        }
    }
--- request
GET /t
--- response_body
scheme: http
--- no_error_log
[error]



=== TEST 2: request.get_scheme() returns https for TLS requests
--- http_config
    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        ssl_certificate $TEST_NGINX_CERT_DIR/test.crt;
        ssl_certificate_key $TEST_NGINX_CERT_DIR/test.key;

        location / {
            content_by_lua_block {
            }

            access_by_lua_block {
                local SDK = require "kong.sdk"
                local sdk = SDK.new()

                ngx.say("scheme: ", sdk.request.get_scheme())
            }
        }
    }
--- config
    location = /t {
        proxy_ssl_verify off;
        proxy_pass https://unix:$TEST_NGINX_HTML_DIR/nginx.sock;
    }
--- request
GET /t
--- response_body
scheme: https
--- no_error_log
[error]



=== TEST 3: request.get_scheme() is normalized
--- config
    location = /t {
        access_by_lua_block {
            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            ngx.say("scheme: ", sdk.request.get_scheme())
        }
    }
--- request
GET HTTP://KONG/t
--- response_body
scheme: http
--- no_error_log
[error]



=== TEST 4: request.get_scheme() errors on non-supported phases
--- http_config
--- config
    location = /t {
        default_type 'text/test';
        access_by_lua_block {
            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            local phases = {
                "set",
                "rewrite",
                "access",
                "content",
                "log",
                "header_filter",
                "body_filter",
                "timer",
                "init_worker",
                "balancer",
                "ssl_cert",
                "ssl_session_store",
                "ssl_session_fetch",
            }

            local data = {}
            local i = 0

            for _, phase in ipairs(phases) do
                ngx.get_phase = function()
                    return phase
                end

                local ok, err = pcall(sdk.request.get_scheme)
                if not ok then
                    i = i + 1
                    data[i] = err
                end
            end

            ngx.say(table.concat(data, "\n"))
        }
    }
--- request
GET /t
--- error_code: 200
--- response_body
kong.request.get_scheme is disabled in the context of set
kong.request.get_scheme is disabled in the context of content
kong.request.get_scheme is disabled in the context of timer
kong.request.get_scheme is disabled in the context of init_worker
kong.request.get_scheme is disabled in the context of balancer
kong.request.get_scheme is disabled in the context of ssl_cert
kong.request.get_scheme is disabled in the context of ssl_session_store
kong.request.get_scheme is disabled in the context of ssl_session_fetch
--- no_error_log
[error]
