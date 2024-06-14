import ComposableArchitecture
import Foundation
import SharedUIComponents
import SwiftUI
import WebKit

struct BrowserView: View {
    @Perception.Bindable var store: StoreOf<CodeiumChatBrowser>
    let webView: WKWebView

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                ZStack {
                    WebView(webView: webView)
                }
            }
            .overlay {
                if store.isLoading {
                    ProgressView()
                }
            }
        }
    }
}

struct WebView: NSViewRepresentable {
    var webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
