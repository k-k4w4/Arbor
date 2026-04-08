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
                Toggle("Gravatar アバターを表示する", isOn: $settings.showGravatar)
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
            Section("高度な設定") {
                HStack {
                    Text("グラフのレーン幅")
                    Spacer()
                    TextField("", value: $settings.graphLaneWidth, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Text("pt")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Git バイナリパス")
                    Spacer()
                    Picker("", selection: $settings.useCustomGitPath) {
                        Text("自動検出").tag(false)
                        Text("カスタム").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                if settings.useCustomGitPath {
                    TextField(text: $settings.customGitPath, prompt: Text("/usr/bin/git")) {
                        EmptyView()
                    }
                    Text("変更はリポジトリ再選択時に反映されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 320)
        .padding(.vertical)
    }
}
