Screen {
    id: root
    background: #F1F5F9

    Label { text: "Preferences" x: 20 y: 14 width: root.width - 40 height: 30 color: #0F172A font_size: 20 bold: true }

    Accordion {
        id: preferences
        x: 20
        y: 56
        width: root.width - 40
        height: 244
        current: app.current
        orientation: vertical
        min_space: 44
        title_background: #E2E8F0
        active_title_background: #2563EB
        title_color: #475569
        active_title_color: #FFFFFF
        background: #FFFFFF
        corner_radius: 10

        AccordionItem {
            id: profile
            title: "Profile"
            on_select: app.show_profile()
            Label { text: "Update your public profile." x: 20 y: 22 width: 320 height: 28 color: #0F172A font_size: 18 bold: true }
        }
        AccordionItem {
            id: notifications
            title: "Notifications"
            on_select: app.show_notifications()
            Label { text: "Choose which alerts you receive." x: 20 y: 22 width: 340 height: 28 color: #0F172A font_size: 18 bold: true }
        }
        AccordionItem {
            id: security
            title: "Security"
            on_select: app.show_security()
            Label { text: "Review passwords and active sessions." x: 20 y: 22 width: 350 height: 28 color: #0F172A font_size: 18 bold: true }
        }
    }
}
