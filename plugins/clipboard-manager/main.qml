import QtQuick
import QtQuick.Controls 2.15
import Quickshell
import Quickshell.Io
import Caelestia
import qs.components
import qs.services

PanelWindow {
    id: root
    
    visible: false
    width: 400
    height: 600

    property string searchText: ""

    function requestToggle() {
        visible = !visible;
    }

    Component.onCompleted: {
        if (typeof CaelestiaApi !== "undefined" && CaelestiaApi.shortcuts) {
            CaelestiaApi.shortcuts.register("clipboard_manager", "Toggle Clipboard Manager", "Meta+V", root.requestToggle);
        }
    }

    // Original data
    ListModel { id: allHistoryModel }
    // Filtered data
    ListModel { id: filteredModel }

    function updateFilteredModel() {
        filteredModel.clear();
        for (let i = 0; i < allHistoryModel.count; i++) {
            let item = allHistoryModel.get(i);
            if (searchText === "" || item.display.toLowerCase().includes(searchText.toLowerCase())) {
                filteredModel.append(item);
            }
        }
    }

    Connections {
        target: allHistoryModel
        function onCountChanged() { updateFilteredModel(); }
    }

    // Fetch history
    Process {
        id: historyProc
        command: ["sh", "-c", "cliphist list"]
        stdout: SplitParser {
            onRead: line => {
                if (line.trim()) {
                    let parts = line.trim().split(/\s+(.*)/);
                    if (parts.length >= 2) {
                        allHistoryModel.append({ id: parts[0], display: parts[1] });
                    }
                }
            }
        }
        Component.onCompleted: running = true
    }

    Column {
        anchors.fill: parent
        spacing: 4

        TextField {
            id: searchField
            width: parent.width
            placeholderText: "Search..."
            onTextChanged: {
                searchText = text;
                updateFilteredModel();
            }
        }

        ListView {
            id: listView
            width: parent.width
            height: parent.height - searchField.height - clearBtn.height - 12
            model: filteredModel
            focus: true
            clip: true

            delegate: ItemDelegate {
                width: listView.width
                text: model.display
                
                // Add Pin button
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Button {
                        text: "📌"
                        onClicked: {
                            Quickshell.execDetached(["sh", "-c", "echo " + model.id + " >> /home/milasabd/.local/share/clipboard-manager/pins.txt"]);
                        }
                    }
                }

                onClicked: {
                    Quickshell.execDetached(["sh", "-c", "cliphist decode " + model.id + " | wl-copy"]);
                    root.visible = false; // Hide on select
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    if (listView.currentItem) {
                        listView.currentItem.clicked();
                    }
                }
            }
        }

        Button {
            id: clearBtn
            width: parent.width
            text: "Clear History"
            onClicked: {
                Quickshell.execDetached(["cliphist", "wipe"]);
                allHistoryModel.clear();
            }
        }
    }
}
