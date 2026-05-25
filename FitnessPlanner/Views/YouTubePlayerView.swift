import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @Binding var isPlaying: Bool

    init(videoID: String, isPlaying: Binding<Bool> = .constant(true)) {
        self.videoID = videoID
        self._isPlaying = isPlaying
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var loadedVideoID: String?
        var hasFinishedLoading: Bool = false
        var desiredIsPlaying: Bool = true

        func apply(isPlaying: Bool) {
            desiredIsPlaying = isPlaying
            guard hasFinishedLoading else { return }
            send(playing: isPlaying)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            hasFinishedLoading = true
            // The iframe needs a beat to register its postMessage listener after load.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.send(playing: self.desiredIsPlaying)
            }
        }

        private func send(playing: Bool) {
            let funcName = playing ? "playVideo" : "pauseVideo"
            let js = """
            (function() {
              var f = document.getElementById('player');
              if (!f || !f.contentWindow) return;
              f.contentWindow.postMessage(JSON.stringify({event:'command',func:'\(funcName)',args:[]}), '*');
            })();
            """
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.loadedVideoID = videoID
            context.coordinator.hasFinishedLoading = false
            webView.loadHTMLString(html(for: videoID), baseURL: URL(string: "https://www.youtube-nocookie.com"))
        }
        context.coordinator.apply(isPlaying: isPlaying)
    }

    private func html(for videoID: String) -> String {
        """
        <!DOCTYPE html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
            <style>
              html, body { margin: 0; padding: 0; background: #000; height: 100%; }
              .wrap { position: relative; width: 100%; padding-bottom: 56.25%; }
              iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
            </style>
          </head>
          <body>
            <div class="wrap">
              <iframe
                id="player"
                src="https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=1&playsinline=1&rel=0&modestbranding=1&mute=1&controls=0&disablekb=1&fs=0&iv_load_policy=3&loop=1&playlist=\(videoID)&enablejsapi=1"
                allow="autoplay; accelerometer; encrypted-media; gyroscope; picture-in-picture"></iframe>
            </div>
          </body>
        </html>
        """
    }
}
