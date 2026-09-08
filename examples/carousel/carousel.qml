Screen {
    id: root
    background: #F1F5F9

    Label { text: "Carousel" x: 20 y: 14 width: 180 height: 30 color: #0F172A font_size: 20 bold: true }
    Label { text: "${app.index + 1} / 3" x: root.width - 120 y: 18 width: 100 height: 22 align: right color: #64748B }

    Carousel {
        id: gallery
        x: 20
        y: 56
        width: root.width - 40
        height: 220
        index: app.index
        direction: right
        loop: true
        background: #FFFFFF
        corner_radius: 10

        CarouselSlide {
            id: ocean
            background: #DBEAFE
            Label { text: "Ocean" x: 24 y: 56 width: ocean.width - 48 height: 44 align: center color: #1E3A8A font_size: 30 bold: true }
        }
        CarouselSlide {
            id: forest
            background: #DCFCE7
            Label { text: "Forest" x: 24 y: 56 width: forest.width - 48 height: 44 align: center color: #14532D font_size: 30 bold: true }
        }
        CarouselSlide {
            id: sunset
            background: #FFEDD5
            Label { text: "Sunset" x: 24 y: 56 width: sunset.width - 48 height: 44 align: center color: #7C2D12 font_size: 30 bold: true }
        }
    }

    Button { text: "Previous" on_tap: app.previous() x: 20 y: 290 width: 110 height: 36 background: #FFFFFF color: #1D4ED8 corner_radius: 8 }
    Button { text: "Next" on_tap: app.next() x: root.width - 130 y: 290 width: 110 height: 36 background: #2563EB color: #FFFFFF corner_radius: 8 }
}
