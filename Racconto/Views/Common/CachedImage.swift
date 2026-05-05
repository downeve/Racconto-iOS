import SwiftUI
import Kingfisher

struct CachedImage: View {
    let url: String?
    var variant: CFVariant = .public
    var contentMode: SwiftUI.ContentMode = .fill

    var body: some View {
        KFImage(cfUrl(url, variant: variant))
            .placeholder { Color(.secondarySystemBackground) }
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }
}
