import SwiftUI

struct BoxWindow: View {
    @Binding var mouseLocation: NSPoint
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .ignoresSafeArea()
        }
    }
} 