import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts
import chatlistmodel
import llm
import download
import network
import mysettings

Rectangle {
    id: chatDrawer

    Theme {
        id: theme
    }

    color: theme.viewBackground

    Rectangle {
        id: borderRight
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 1
        color: theme.dividerColor
    }

    Item {
        anchors.top: parent.top
        anchors.bottom: removeAllButtonContainer.top
        anchors.left: parent.left
        anchors.right: borderRight.left

        Accessible.role: Accessible.Pane
        Accessible.name: qsTr("Drawer")
        Accessible.description: qsTr("Main navigation drawer")

        MySettingsButton {
            id: newChat
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            font.pixelSize: theme.fontSizeLarger
            topPadding: 24
            bottomPadding: 24
            text: qsTr("\uFF0B New Chat")
            Accessible.description: qsTr("Create a new chat")
            onClicked: {
                ChatListModel.addChat()
                conversationList.positionViewAtIndex(0, ListView.Beginning)
                Network.trackEvent("new_chat", {"number_of_chats": ChatListModel.count})
            }
        }

        Rectangle {
            id: divider
            anchors.top: newChat.bottom
            anchors.margins: 20
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: theme.dividerColor
        }

        ScrollView {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 15
            anchors.top: divider.bottom
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 15
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            clip: true

            ListView {
                id: conversationList
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                model: ChatListModel

                Component.onCompleted: ChatListModel.loadChats()

                ScrollBar.vertical: ScrollBar {
                    parent: conversationList.parent
                    anchors.top: conversationList.top
                    anchors.left: conversationList.right
                    anchors.bottom: conversationList.bottom
                }

                Component {
                    id: sectionHeading
                    Rectangle {
                        width: ListView.view.width
                        height: childrenRect.height
                        color: "transparent"
                        property bool isServer: ChatListModel.get(parent.index) && ChatListModel.get(parent.index).isServer
                        visible: !isServer || MySettings.serverChat

                        required property string section

                        Text {
                            leftPadding: 10
                            rightPadding: 10
                            topPadding: 15
                            bottomPadding: 5
                            text: parent.section
                            color: theme.chatDrawerSectionHeader
                            font.pixelSize: theme.fontSizeSmallest
                        }
                    }
                }

                section.property: "section"
                section.criteria: ViewSection.FullString
                section.delegate: sectionHeading

                delegate: Rectangle {
                    id: chatRectangle
                    width: conversationList.width
                    height: chatNameBox.height + 20
                    property bool isCurrent: ChatListModel.currentChat === ChatListModel.get(index)
                    property bool isServer: ChatListModel.get(index) && ChatListModel.get(index).isServer
                    property bool trashQuestionDisplayed: false
                    visible: !isServer || MySettings.serverChat
                    z: isCurrent ? 199 : 1
                    color: isCurrent ? theme.selectedBackground : "transparent"
                    border.width: isCurrent
                    border.color: theme.dividerColor
                    radius: 10

                    Rectangle {
                        id: chatNameBox
                        height: chatName.height
                        anchors.left: parent.left
                        anchors.right: trashButton.left
                        anchors.verticalCenter: chatRectangle.verticalCenter
                        anchors.leftMargin: 5
                        anchors.rightMargin: 5
                        radius: 5
                        color: chatName.readOnly ? "transparent" : theme.chatNameEditBgColor

                        TextField {
                            id: chatName
                            anchors.left: parent.left
                            anchors.right: editButton.left
                            anchors.verticalCenter: chatNameBox.verticalCenter
                            topPadding: 5
                            bottomPadding: 5
                            color: theme.styledTextColor
                            focus: false
                            readOnly: true
                            wrapMode: Text.NoWrap
                            hoverEnabled: false // Disable hover events on the TextArea
                            selectByMouse: false // Disable text selection in the TextArea
                            font.pixelSize: theme.fontSizeLarge
                            font.bold: true
                            text: readOnly ? metrics.elidedText : name
                            horizontalAlignment: TextInput.AlignLeft
                            opacity: trashQuestionDisplayed ? 0.5 : 1.0
                            TextMetrics {
                                id: metrics
                                font: chatName.font
                                text: name
                                elide: Text.ElideRight
                                elideWidth: chatName.width - 15
                            }
                            background: Rectangle {
                                color: "transparent"
                            }
                            onEditingFinished: {
                                // Work around a bug in qml where we're losing focus when the whole window
                                // goes out of focus even though this textfield should be marked as not
                                // having focus
                                if (chatName.readOnly)
                                    return;
                                changeName();
                            }
                            function changeName() {
                                Network.trackChatEvent("rename_chat");
                                ChatListModel.get(index).name = chatName.text;
                                chatName.focus = false;
                                chatName.readOnly = true;
                                chatName.selectByMouse = false;
                            }
                            TapHandler {
                                onTapped: {
                                    if (isCurrent)
                                        return;
                                    ChatListModel.currentChat = ChatListModel.get(index);
                                }
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: text
                            Accessible.description: qsTr("Select the current chat or edit the chat when in edit mode")
                        }
                        MyToolButton {
                            id: editButton
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            imageWidth: 24
                            imageHeight: 24
                            visible: isCurrent && !isServer && chatName.readOnly
                            opacity: trashQuestionDisplayed ? 0.5 : 1.0
                            source: "qrc:/gpt4all/icons/edit.svg"
                            onClicked: {
                                chatName.focus = true;
                                chatName.readOnly = false;
                                chatName.selectByMouse = true;
                            }
                            Accessible.name: qsTr("Edit chat name")
                        }
                        MyToolButton {
                            id: okButton
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            imageWidth: 24
                            imageHeight: 24
                            visible: isCurrent && !isServer && !chatName.readOnly
                            opacity: trashQuestionDisplayed ? 0.5 : 1.0
                            source: "qrc:/gpt4all/icons/check.svg"
                            onClicked: chatName.changeName()
                            Accessible.name: qsTr("Save chat name")
                        }
                    }

                    MyToolButton {
                        id: trashButton
                        anchors.verticalCenter: chatNameBox.verticalCenter
                        anchors.right: chatRectangle.right
                        anchors.rightMargin: 10
                        imageWidth: 24
                        imageHeight: 24
                        visible: isCurrent && !isServer
                        source: "qrc:/gpt4all/icons/trash.svg"
                        onClicked: {
                            trashQuestionDisplayed = true
                            timer.start()
                        }
                        Accessible.name: qsTr("Delete chat")
                    }
                    Rectangle {
                        id: trashSureQuestion
                        anchors.top: trashButton.bottom
                        anchors.topMargin: 10
                        anchors.right: trashButton.right
                        width: childrenRect.width
                        height: childrenRect.height
                        color: chatRectangle.color
                        visible: isCurrent && trashQuestionDisplayed
                        opacity: 1.0
                        radius: 10
                        z: 200
                        Row {
                            spacing: 10
                            Button {
                                id: checkMark
                                width: 30
                                height: 30
                                contentItem: Text {
                                    color: theme.textErrorColor
                                    text: "\u2713"
                                    font.pixelSize: theme.fontSizeLarger
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    width: 30
                                    height: 30
                                    color: "transparent"
                                }
                                onClicked: {
                                    Network.trackChatEvent("remove_chat")
                                    ChatListModel.removeChat(ChatListModel.get(index))
                                }
                                Accessible.role: Accessible.Button
                                Accessible.name: qsTr("Confirm chat deletion")
                            }
                            Button {
                                id: cancel
                                width: 30
                                height: 30
                                contentItem: Text {
                                    color: theme.textColor
                                    text: "\u2715"
                                    font.pixelSize: theme.fontSizeLarger
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    width: 30
                                    height: 30
                                    color: "transparent"
                                }
                                onClicked: {
                                    trashQuestionDisplayed = false
                                }
                                Accessible.role: Accessible.Button
                                Accessible.name: qsTr("Cancel chat deletion")
                            }
                        }
                    }
                    Timer {
                        id: timer
                        interval: 3000; running: false; repeat: false
                        onTriggered: trashQuestionDisplayed = false
                    }
                }

                Accessible.role: Accessible.List
                Accessible.name: qsTr("List of chats")
                Accessible.description: qsTr("List of chats in the drawer dialog")
            }
        }
    }

    Rectangle {
        id: removeAllButtonContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 60
        color: theme.viewBackground
        border.color: theme.dividerColor
        border.width: 1

        Button {
            id: removeAllButton
            anchors.centerIn: parent
            width: parent.width - 40
            height: 40
            text: qsTr("Remove All Chats")
            font.pixelSize: theme.fontSizeLarger
            color: "white"
            background: Rectangle {
                color: "red"
                radius: 10
            }
            onClicked: {
                removeAllConfirmation.visible = true
            }
            Accessible.name: qsTr("Remove all chats")
            Accessible.description: qsTr("Button to remove all chats with confirmation")
        }
    }

    Rectangle {
        id: removeAllConfirmation
        anchors.centerIn: parent
        width: 300
        height: 150
        color: theme.viewBackground
        radius: 10
        visible: false
        border.color: theme.dividerColor
        border.width: 1
        z: 100

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: qsTr("Are you sure you want to remove all chats?")
                font.pixelSize: theme.fontSizeLarger
                color: theme.textColor
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                spacing: 20
                anchors.horizontalCenter: parent.horizontalCenter

                Button {
                    id: confirmRemoveAll
                    text: qsTr("Yes")
                    font.pixelSize: theme.fontSizeLarger
                    color: "white"
                    background: Rectangle {
                        color: "red"
                        radius: 10
                    }
                    onClicked: {
                        removeAllChats()
                        removeAllConfirmation.visible = false
                    }
                    Accessible.name: qsTr("Confirm remove all chats")
                    Accessible.description: qsTr("Button to confirm the removal of all chats")
                }

                Button {
                    id: cancelRemoveAll
                    text: qsTr("No")
                    font.pixelSize: theme.fontSizeLarger
                    color: theme.textColor
                    background: Rectangle {
                        color: theme.viewBackground
                        radius: 10
                        border.color: theme.dividerColor
                        border.width: 1
                    }
                    onClicked: {
                        removeAllConfirmation.visible = false
                    }
                    Accessible.name: qsTr("Cancel remove all chats")
                    Accessible.description: qsTr("Button to cancel the removal of all chats")
                }
            }
        }

        Accessible.name: qsTr("Confirmation dialog")
        Accessible.description: qsTr("Dialog asking for confirmation to remove all chats")
    }

    function removeAllChats() {
        for (var i = ChatListModel.count - 1; i >= 0; i--) {
            ChatListModel.removeChat(ChatListModel.get(i))
        }
        Network.trackChatEvent("remove_all_chats")
    }
}
