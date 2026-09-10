Screen {
    id: root
    background: #F1F5F9

    Label { text: "Project" x: 20 y: 14 width: root.width - 40 height: 30 color: #0F172A font_size: 20 bold: true }

    Scroll {
        id: navigation_scroll
        x: 20
        y: 56
        width: root.width - 40
        height: 240
        background: #FFFFFF

        TreeView {
            id: navigation
            width: navigation_scroll.width
            height: 240
            row_height: 38
            spacing: 3
            indent: 24
            disclosure_width: 30
            row_background: #FFFFFF
            selected_background: #DBEAFE
            color: #334155
            selected_color: #1D4ED8

            TreeNode {
                id: docs
                text: "Documentation"
                expanded: app.docs_open
                on_toggle: app.toggle_docs()
                TreeNode {
                    id: welcome
                    text: "Welcome"
                    selected: app.selected == "welcome"
                    on_select: app.select_welcome()
                }
                TreeNode {
                    id: installation
                    text: "Installation"
                    selected: app.selected == "installation"
                    on_select: app.select_installation()
                }
            }
            TreeNode {
                id: license
                text: "License"
                selected: app.selected == "license"
                on_select: app.select_license()
            }
        }
    }

    Label { text: "Selected: ${app.selected}" x: 20 y: 310 width: root.width - 40 height: 24 align: center color: #166534 }
}
