using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;

namespace SkpPrinterUsb
{
    /// <summary>
    /// DCP-T830DW telemetry via Brother HttpToUsbBridge on localhost.
    /// </summary>
    sealed class HttpBridgeSession : IDisposable
    {
        const string BaseUrl = "http://127.0.0.1:60910";
        const string MaintenancePath = "/general/information.html?kind=item";
        const int CallTimeoutMs = 15000;

        readonly CookieContainer _cookies = new CookieContainer();
        readonly HttpClient _http;
        string _password;

        public HttpBridgeSession()
        {
            var handler = new HttpClientHandler
            {
                CookieContainer = _cookies,
                UseCookies = true,
                AllowAutoRedirect = true,
                AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate,
            };
            _http = new HttpClient(handler)
            {
                BaseAddress = new Uri(BaseUrl),
                Timeout = TimeSpan.FromMilliseconds(CallTimeoutMs),
            };
            _http.DefaultRequestHeaders.ExpectContinue = false;
        }

        public void SetPassword(string password)
        {
            if (string.IsNullOrWhiteSpace(password)) return;
            var next = password.Trim();
            if (_password != next)
            {
                _password = next;
                ClearSession();
            }
        }

        public Snapshot Capture(bool full)
        {
            try
            {
                if (string.IsNullOrEmpty(_password))
                {
                    return Snapshot.Fail("password_missing");
                }

                var snapshot = new Snapshot { Ok = true, Connected = true };
                EnsureLoggedIn();
                var monitor = GetString("/home/monitor.html");
                BridgeHtml.ApplyMonitor(monitor, snapshot);

                string maintenance;
                try
                {
                    maintenance = GetString(MaintenancePath);
                }
                catch (BridgeAuthException)
                {
                    ClearSession();
                    EnsureLoggedIn();
                    maintenance = GetString(MaintenancePath);
                }

                if (LooksLikeLoginPage(maintenance))
                {
                    ClearSession();
                    EnsureLoggedIn();
                    maintenance = GetString(MaintenancePath);
                }
                if (LooksLikeLoginPage(maintenance))
                {
                    return Snapshot.Fail("auth_failed");
                }

                BridgeHtml.ApplyMaintenance(maintenance, snapshot, includeErrors: full);
                return snapshot;
            }
            catch (BridgeAuthException)
            {
                ClearSession();
                return Snapshot.Fail("auth_failed");
            }
            catch (HttpRequestException)
            {
                ClearSession();
                return Snapshot.Fail("bridge_unreachable");
            }
            catch (TaskCanceledException)
            {
                ClearSession();
                return Snapshot.Fail("usb_timeout");
            }
            catch (Exception ex)
            {
                ClearSession();
                return Snapshot.Fail(OneLine(ex));
            }
        }

        void EnsureLoggedIn()
        {
            if (HasAuthCookie()) return;
            if (string.IsNullOrEmpty(_password))
            {
                throw new InvalidOperationException("password_missing");
            }

            using (var content = new FormUrlEncodedContent(new[]
            {
                new KeyValuePair<string, string>("B185", _password),
                new KeyValuePair<string, string>("loginurl", MaintenancePath),
            }))
            {
                // Do not log form body — contains the printer password.
                var response = _http.PostAsync("/home/status.html", content).GetAwaiter().GetResult();
                var body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
                if (!HasAuthCookie() || LooksLikePasswordError(body) || IsLoginErrorLocation(response))
                {
                    ClearSession();
                    throw new BridgeAuthException();
                }
            }
        }

        string GetString(string path)
        {
            var response = _http.GetAsync(path).GetAwaiter().GetResult();
            if ((int)response.StatusCode == 302 || (int)response.StatusCode == 301)
            {
                var location = response.Headers.Location != null
                    ? response.Headers.Location.OriginalString
                    : "";
                if (location.IndexOf("loginerror", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    location.IndexOf("passerror", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    throw new BridgeAuthException();
                }
            }
            response.EnsureSuccessStatusCode();
            var html = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
            if (LooksLikeLoginPage(html) && path.IndexOf("information", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                throw new BridgeAuthException();
            }
            return html;
        }

        bool HasAuthCookie()
        {
            var cookies = _cookies.GetCookies(new Uri(BaseUrl));
            foreach (Cookie cookie in cookies)
            {
                if (cookie != null &&
                    string.Equals(cookie.Name, "AuthCookie", StringComparison.OrdinalIgnoreCase) &&
                    !string.IsNullOrEmpty(cookie.Value))
                {
                    return true;
                }
            }
            return false;
        }

        void ClearSession()
        {
            var cookies = _cookies.GetCookies(new Uri(BaseUrl));
            foreach (Cookie cookie in cookies)
            {
                if (cookie == null) continue;
                cookie.Expired = true;
            }
        }

        static bool LooksLikeLoginPage(string html)
        {
            if (string.IsNullOrEmpty(html)) return true;
            if (html.IndexOf("Please Login", StringComparison.OrdinalIgnoreCase) >= 0) return true;
            if (html.IndexOf("Password Error", StringComparison.OrdinalIgnoreCase) >= 0) return true;
            if (html.IndexOf("id=\"LogBox\"", StringComparison.OrdinalIgnoreCase) >= 0 &&
                html.IndexOf("Maintenance Information", StringComparison.OrdinalIgnoreCase) < 0)
            {
                return true;
            }
            return false;
        }

        static bool LooksLikePasswordError(string html)
        {
            return !string.IsNullOrEmpty(html) &&
                   html.IndexOf("Password Error", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        static bool IsLoginErrorLocation(HttpResponseMessage response)
        {
            if (response == null || response.Headers.Location == null) return false;
            var location = response.Headers.Location.OriginalString;
            return location.IndexOf("passerror", StringComparison.OrdinalIgnoreCase) >= 0 ||
                   location.IndexOf("loginerror", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        static string OneLine(Exception ex)
        {
            var inner = ex.GetBaseException();
            var message = inner == null ? ex.Message : inner.Message;
            if (string.IsNullOrWhiteSpace(message)) return "usb_helper_failed";
            return message.Replace("\r", " ").Replace("\n", " ").Trim();
        }

        public void Dispose()
        {
            _http.Dispose();
        }
    }

    sealed class BridgeAuthException : Exception
    {
    }
}
