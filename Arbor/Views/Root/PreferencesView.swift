import SwiftUI

struct PreferencesView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("一般") {
                Toggle("日時を絶対表示する", isOn: $settings.showAbsoluteDates)
                Toggle("変更ファイルをツリー表示する", isOn: $settings.showFileTree)
                Toggle("Split diff 表示する", isOn: $settings.showSplitDiff)
            }
            Section("外観") {
                Picker("テーマ", selection: $settings.appearanceMode) {
                    Text("システムに従う").tag(0)
                    Text("ライト").tag(1)
                    Text("ダーク").tag(2)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
        .frame(width: 320)
        .padding(.vertical)
    }
}
