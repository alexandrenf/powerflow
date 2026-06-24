import SwiftUI

struct PopoverView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        PowerStatusView(isPopover: true)
            .padding(12)
            .frame(width: 352, height: 224)
            .contentShape(Rectangle())
            .onTapGesture {
                appModel.openMainWindow()
            }
    }
}
