import WebKit

enum WebViewWarmup {
    nonisolated(unsafe) private static var warmupWebView: WKWebView?

    static func warm() {
        guard warmupWebView == nil else { return }
        let webView = WKWebView(frame: .zero)
        webView.loadHTMLString(html, baseURL: nil)
        warmupWebView = webView
    }

    private static let html = """
    <!DOCTYPE html>
    <html>
      <head>
        <link rel="preconnect" href="https://www.youtube-nocookie.com" crossorigin>
        <link rel="preconnect" href="https://www.youtube.com" crossorigin>
        <link rel="dns-prefetch" href="https://i.ytimg.com">
      </head>
      <body></body>
    </html>
    """
}
