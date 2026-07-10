import SwiftUI
import UIKit

/// Displays an image inside a secure-text-entry canvas so it is blanked in
/// screenshots and screen recordings (anti-cheat: the reference photo must
/// not be screenshottable and then shown to the camera). Falls back to a
/// plain image view if the platform stops exposing the secure canvas —
/// display must never break.
struct SecureImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIView {
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        // The secure field's first subview is the render canvas that iOS
        // blanks out in screenshots; content added to it inherits that.
        let container: UIView = field.subviews.first ?? UIView()
        container.isUserInteractionEnabled = false
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView.subviews.compactMap { $0 as? UIImageView }).first?.image = image
    }
}
