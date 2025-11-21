import SwiftUI

struct SelectedIndex: Identifiable {
    let id = UUID()
    let value: Int
}

struct GroupDetailView: View {

    @ObservedObject var vm: GroupDetailViewModel
    @State private var selected: SelectedIndex? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        VStack(spacing: 0) {
            
            ScrollView {
                let size = (UIScreen.main.bounds.width - 16) / 3

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(vm.images.indices, id: \.self) { i in
                        ZStack {
                            if let img = vm.images[i] {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: size, height: size)
                                    .clipped()
                                    .onTapGesture {
                                        selected = SelectedIndex(value: i)
                                    }
                            } else {
                                ZStack {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: size, height: size)
                                    
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .onAppear {
                            vm.loadImageIfNeeded(at: i)
                        }
                    }
                }
                .padding(4)
            }
        }
        .navigationTitle("\(vm.groupName.uppercased()) (\(vm.assets.count))")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selected) { item in
            ImageDetailView(
                assets: vm.assets,
                startIndex: item.value
            )
        }
    }
}

#if DEBUG
struct GroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GroupDetailView(
                vm: GroupDetailViewModel(
                    scanViewModel: ScanViewModel(),
                    group: .a,
                    groupName: "Sample"
                )
            )
        }
    }
}
#endif
