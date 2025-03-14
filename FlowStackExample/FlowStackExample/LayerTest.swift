//
//  LayerTest.swift
//  FlowStackExample
//
//  Created by Brody on 3/13/25.
//

import Foundation
import SwiftUI
import FlowStack

struct LayerView: View {
    @Environment(\.flowDismiss) var flowDismiss
    var body: some View {
        ZStack{
            Color.black.ignoresSafeArea()
            VStack {
                Button(action: {
                    flowDismiss()
                }, label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color(uiColor: .darkGray))
                        .padding(10)
                        .background {
                            Circle()
                                .foregroundStyle(Color(uiColor: .white))
                        }
                })
                Text("Layer 2 Test")
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    .font(.system(size: 34))
            }
        }
    }
}

#Preview{
    LayerView()
}
