import SwiftUI
import WebKit

struct TravelToolView: View {
    let title: String
    let url: String

    var body: some View {
        WebViewRepresentable(url: URL(string: url)!)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}
