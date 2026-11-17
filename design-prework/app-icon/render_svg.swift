import AppKit
import WebKit
// usage: render <svg> <out.png> <size>
let a = CommandLine.arguments
let svgURL = URL(fileURLWithPath: a[1]); let out = a[2]; let size = CGFloat(Double(a[3])!)
let app = NSApplication.shared
let cfg = WKWebViewConfiguration()
let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: size, height: size), configuration: cfg)
wv.setValue(false, forKey: "drawsBackground")
let svg = try! String(contentsOf: svgURL, encoding: .utf8)
let html = "<html><body style='margin:0;background:transparent'><img src='data:image/svg+xml;base64,\(Data(svg.utf8).base64EncodedString())' style='width:\(Int(size))px;height:\(Int(size))px;display:block'></body></html>"
class D: NSObject, WKNavigationDelegate {
  func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      let c = WKSnapshotConfiguration(); c.rect = w.bounds; c.snapshotWidth = NSNumber(value: Double(w.bounds.width))
      w.takeSnapshot(with: c) { img, err in
        guard let img = img, let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print(err as Any); exit(1) }
        let rep = NSBitmapImageRep(cgImage: cg)
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
        print("wrote \(out) \(cg.width)x\(cg.height)"); exit(0)
      }
    }
  }
}
let d = D(); wv.navigationDelegate = d
let win = NSWindow(contentRect: wv.frame, styleMask: [.borderless], backing: .buffered, defer: false)
win.backgroundColor = .clear; win.isOpaque = false; win.contentView = wv
wv.loadHTMLString(html, baseURL: nil)
app.run()
