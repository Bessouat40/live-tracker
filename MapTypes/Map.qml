MapView {
    id: view
    map.zoomLevel: (maximumZoomLevel - minimumZoomLevel)/2
    map.center {
        latitude: 59.9485
        longitude: 10.7686
    }
}