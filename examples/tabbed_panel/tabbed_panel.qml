Screen {
    id: root
    background: #F1F5F9

    Label { text: "Settings" x: 20 y: 14 width: root.width - 40 height: 30 color: #0F172A font_size: 20 bold: true }

    TabbedPanel {
        id: settings
        x: 20
        y: 56
        width: root.width - 40
        height: 220
        current: app.current
        tab_width: 118
        tab_height: 40
        tab_background: #E2E8F0
        active_tab_background: #FFFFFF
        tab_color: #475569
        active_tab_color: #1D4ED8
        background: #FFFFFF
        corner_radius: 10

        Tab {
            id: overview
            text: "Overview"
            on_select: app.show_overview()
            Label { text: "Account overview" x: 24 y: 30 width: 300 height: 32 color: #0F172A font_size: 22 bold: true }
            Label { text: "Reusable content for the active tab." x: 24 y: 70 width: 330 height: 24 color: #64748B }
        }
        Tab {
            id: activity
            text: "Activity"
            on_select: app.show_activity()
            Label { text: "Recent activity" x: 24 y: 30 width: 300 height: 32 color: #14532D font_size: 22 bold: true }
        }
        Tab {
            id: security
            text: "Security"
            on_select: app.show_security()
            Label { text: "Security options" x: 24 y: 30 width: 300 height: 32 color: #7C2D12 font_size: 22 bold: true }
        }
    }
}
