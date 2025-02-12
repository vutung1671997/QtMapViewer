// Copyright (C) 2023 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR BSD-3-Clause
import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
import "../helper.js" as Helper

//! [top]
MapView {
    id: view
//! [top]
    property variant markers
    property variant mapItems
    property int markerCounter: 0 // counter for total amount of markers. Resets to 0 when number of markers = 0
    property int currentMarker
    property bool followme: false
    property variant scaleLengths: [5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000, 1000000, 2000000]
    property alias routeQuery: routeQuery
    property alias routeModel: routeModel
    property alias geocodeModel: geocodeModel
    property alias slidersExpanded: sliders.expanded

    // Add properties for initial coordinates
    property double initialLat: 21.02860193565997
    property double initialLon: 105.8357515048705
    property bool hasInitialCoordinates: true

    // Add property for initial address
    property string initialAddress: ""

    signal showGeocodeInfo()
    signal geocodeFinished()
    signal routeError()
    signal coordinatesCaptured(double latitude, double longitude)
    signal showMainMenu(variant coordinate)
    signal showMarkerMenu(variant coordinate)
    signal showRouteMenu(variant coordinate)
    signal showPointMenu(variant coordinate)
    signal showRouteList()
    signal addressFound(string address)
    signal suggestionSelected(string address, double lat, double lon)

    // Add at the top of the file, after imports
    QtObject {
        id: config
        readonly property bool enableDebugOutput: false  // Set to true to show debug rectangle
        readonly property bool enableConsoleLog: true   // Set to true to show console logs
        readonly property bool enablePythonLog: true    // Set to true to send logs to Python
        readonly property bool enableSearchLogs: true   // Set to true to log search-related events
        readonly property bool enableMapLogs: false     // Set to true to log map-related events
    }

    function log(message, type = "general") {
        try {
            // Check if this type of log should be shown
            let shouldLog = false
            switch(type) {
                case "search":
                    shouldLog = config.enableSearchLogs
                    break
                case "map":
                    shouldLog = config.enableMapLogs
                    break
                default:
                    shouldLog = true
            }

            if (!shouldLog) return

            // Console logging
            if (config.enableConsoleLog) {
                console.log("QML:", message)
            }

            // Debug output rectangle
            if (config.enableDebugOutput && debugOutput && debugOutput.addLog) {
                debugOutput.addLog(message)
            }

            // Python logging
            if (config.enablePythonLog && typeof logger !== "undefined" && logger !== null) {
                logger.log(message)
            }
        } catch (e) {
            console.log("Error in log function:", e)
        }
    }

    function geocodeMessage()
    {
        var street, district, city, county, state, countryCode, country, postalCode, latitude, longitude, text
        latitude = Math.round(geocodeModel.get(0).coordinate.latitude * 10000) / 10000
        longitude =Math.round(geocodeModel.get(0).coordinate.longitude * 10000) / 10000
        street = geocodeModel.get(0).address.street
        district = geocodeModel.get(0).address.district
        city = geocodeModel.get(0).address.city
        county = geocodeModel.get(0).address.county
        state = geocodeModel.get(0).address.state
        countryCode = geocodeModel.get(0).address.countryCode
        country = geocodeModel.get(0).address.country
        postalCode = geocodeModel.get(0).address.postalCode

        text = "<b>Latitude:</b> " + latitude + "<br/>"
        text +="<b>Longitude:</b> " + longitude + "<br/>" + "<br/>"
        if (street) text +="<b>Street: </b>"+ street + " <br/>"
        if (district) text +="<b>District: </b>"+ district +" <br/>"
        if (city) text +="<b>City: </b>"+ city + " <br/>"
        if (county) text +="<b>County: </b>"+ county + " <br/>"
        if (state) text +="<b>State: </b>"+ state + " <br/>"
        if (countryCode) text +="<b>Country code: </b>"+ countryCode + " <br/>"
        if (country) text +="<b>Country: </b>"+ country + " <br/>"
        if (postalCode) text +="<b>PostalCode: </b>"+ postalCode + " <br/>"
        return text
    }

    function calculateScale()
    {
        var coord1, coord2, dist, text, f
        f = 0
        coord1 = view.map.toCoordinate(Qt.point(0,scale.y))
        coord2 = view.map.toCoordinate(Qt.point(0+scaleImage.sourceSize.width,scale.y))
        dist = Math.round(coord1.distanceTo(coord2))

        if (dist === 0) {
            // not visible
        } else {
            for (var i = 0; i < scaleLengths.length-1; i++) {
                if (dist < (scaleLengths[i] + scaleLengths[i+1]) / 2 ) {
                    f = scaleLengths[i] / dist
                    dist = scaleLengths[i]
                    break;
                }
            }
            if (f === 0) {
                f = dist / scaleLengths[i]
                dist = scaleLengths[i]
            }
        }

        text = Helper.formatDistance(dist)
        scaleImage.width = (scaleImage.sourceSize.width * f) - 2 * scaleImageLeft.sourceSize.width
        scaleText.text = text
    }

    function deleteMarkers()
    {
        var count = view.markers.length
        for (var i = count-1; i>=0; i--){
            view.map.removeMapItem(view.markers[i])
        }
        view.markers = []
    }

    function addMarker()
    {
        var count = view.markers.length
        markerCounter++
        var marker = Qt.createQmlObject ('Marker {}', map)
        view.map.addMapItem(marker)
        marker.z = view.map.z+1
        marker.coordinate = tapHandler.lastCoordinate
        markers.push(marker)
    }

    function deleteMarker(index)
    {
        //update list of markers
        var myArray = []
        var count = view.markers.length
        for (var i = 0; i<count; i++){
            if (index !== i) myArray.push(view.markers[i])
        }

        view.map.removeMapItem(view.markers[index])
        view.markers[index].destroy()
        view.markers = myArray
        if (markers.length === 0) markerCounter = 0
    }

    function calculateMarkerRoute()
    {
        routeQuery.clearWaypoints();
        for (var i = currentMarker; i< view.markers.length; i++){
            routeQuery.addWaypoint(markers[i].coordinate)
        }
        routeQuery.travelModes = RouteQuery.CarTravel
        routeQuery.routeOptimizations = RouteQuery.ShortestRoute

        routeModel.update();
    }

    function calculateCoordinateRoute(startCoordinate, endCoordinate)
    {
        //! [routerequest0]
        // clear away any old data in the query
        routeQuery.clearWaypoints();
        // add the start and end coords as waypoints on the route
        routeQuery.addWaypoint(startCoordinate)
        routeQuery.addWaypoint(endCoordinate)
        routeQuery.travelModes = RouteQuery.CarTravel
        routeQuery.routeOptimizations = RouteQuery.FastestRoute
        //! [routerequest0]

        //! [routerequest1]
        routeModel.update();
        //! [routerequest1]

        //! [routerequest2]
        // center the map on the start coord
        view.map.center = startCoordinate;
        //! [routerequest2]
    }

    function geocode(fromAddress)
    {
        //! [geocode1]
        // send the geocode request
        geocodeModel.query = fromAddress
        geocodeModel.update()
        //! [geocode1]
    }

    // Add a function to cancel ongoing requests
    function cancelSearchRequests() {
        // Cancel geocoding request
        if (geocodeModel.status === GeocodeModel.Loading) {
            geocodeModel.reset()
            log("Cancelled ongoing geocoding request")
        }
        
        // Cancel suggestion request
        if (suggestionModel.status === GeocodeModel.Loading) {
            suggestionModel.reset()
            log("Cancelled ongoing suggestion request")
        }
    }

//! [coord]
    map.zoomLevel: (maximumZoomLevel - minimumZoomLevel)/2
    map.center {
        // The Qt Company in Oslo
        latitude: 59.9485
        longitude: 10.7686
    }
//! [coord]

    // Search bar with suggestions
    Rectangle {
        id: searchBar
        z: view.map.z + 3
        width: parent.width * 0.8
        height: 40
        color: "white"
        radius: 5
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            margins: 10
        }
        border.color: "#CCCCCC"
        border.width: 1

        TextInput {
            id: searchInput
            anchors {
                left: parent.left
                right: searchButton.left
                verticalCenter: parent.verticalCenter
                margins: 10
            }
            font.pixelSize: 14
            clip: true
            focus: true
            
            // Add these properties to make the input more visible
            color: "black"
            selectionColor: "#007AFF"
            selectedTextColor: "white"
            
            // Add placeholder text
            Text {
                anchors.fill: parent
                text: "Search location..."
                color: "#999999"
                visible: !searchInput.text && !searchInput.activeFocus
                font.pixelSize: 14
            }
            
            // Add more basic logging
            onActiveFocusChanged: {
                log("Search input focus changed: " + activeFocus)
            }
            
            onTextChanged: {
                log("Search text changed: " + text, "search")
                // Cancel any ongoing requests
                cancelSearchRequests()
                // Reset suggestion list visibility
                suggestionList.visible = false
                
                if (text.length > 2) {
                    // Restart the 2-second timer
                    suggestionTimer.restart()
                    log("Started suggestion timer", "search")
                } else {
                    suggestionTimer.stop()
                }
            }
            
            Keys.onReturnPressed: searchButton.clicked()
            Keys.onEnterPressed: searchButton.clicked()
            Keys.onDownPressed: {
                if (suggestionList.visible) {
                    suggestionList.currentIndex = 0
                    suggestionList.forceActiveFocus()
                }
            }
        }

        Rectangle {
            id: searchButton
            width: height
            height: parent.height
            color: "#007AFF"
            radius: 5
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }

            Text {
                anchors.centerIn: parent
                text: "🔍"
                color: "white"
                font.pixelSize: 16
            }

            TapHandler {
                onTapped: {
                    log("Search button tapped")
                    if (searchInput.text.length > 0) {
                        log("Initiating search for: " + searchInput.text)
                        try {
                            log("Setting geocodeModel query...")
                            geocodeModel.query = searchInput.text
                            log("Query set to: " + geocodeModel.query)
                            log("Calling geocodeModel.update()...")
                            geocodeModel.update()
                            log("Update called successfully")
                            suggestionList.visible = false
                        } catch (e) {
                            log("Error during search: " + e)
                        }
                    } else {
                        log("Search text is empty")
                    }
                }
            }
        }

        // Suggestions list
        Rectangle {
            id: suggestionList
            visible: false
            width: parent.width
            height: Math.min(200, listView.contentHeight)
            anchors.top: parent.bottom
            anchors.left: parent.left
            color: "white"
            border.color: "#CCCCCC"
            border.width: 1
            clip: true

            ListView {
                id: listView
                anchors.fill: parent
                model: suggestionModel
                delegate: Item {
                    width: suggestionList.width
                    height: 40

                    Rectangle {
                        anchors.fill: parent
                        color: listView.currentIndex === index ? "#f0f0f0" : "white"

                        Text {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: 10
                            }
                            text: locationData.address.text || locationData.address.street + ", " + locationData.address.city
                            elide: Text.ElideRight
                        }

                        TapHandler {
                            onTapped: {
                                searchInput.text = locationData.address.text || locationData.address.street + ", " + locationData.address.city
                                geocodeModel.query = searchInput.text
                                geocodeModel.update()
                                suggestionList.visible = false
                            }
                        }
                    }
                }

                Keys.onReturnPressed: {
                    if (currentIndex >= 0) {
                        searchInput.text = suggestionModel.get(currentIndex).address.text || 
                                         suggestionModel.get(currentIndex).address.street + ", " + 
                                         suggestionModel.get(currentIndex).address.city
                        geocodeModel.query = searchInput.text
                        geocodeModel.update()
                        suggestionList.visible = false
                        searchInput.forceActiveFocus()
                    }
                }
            }
        }
    }

    // Add a busy indicator while searching
    BusyIndicator {
        id: busyIndicator
        anchors.centerIn: parent
        running: geocodeModel.status === GeocodeModel.Loading
        visible: running
    }

    focus: true
    map.onCopyrightLinkActivated: Qt.openUrlExternally(link)

    map.onCenterChanged:{
        log("Map center changed: " + map.center, "map")
        scaleTimer.restart()
        if (view.followme)
            if (view.map.center != positionSource.position.coordinate) view.followme = false
    }

    map.onZoomLevelChanged:{
        scaleTimer.restart()
        if (view.followme) view.map.center = positionSource.position.coordinate
    }

    onWidthChanged:{
        scaleTimer.restart()
    }

    onHeightChanged:{
        scaleTimer.restart()
    }

    Component.onCompleted: {
        try {
            log("MapView completed")
            if (map && map.plugin) {
                log("Map plugin name: " + map.plugin.name)
                log("Map plugin available: " + map.plugin.available)
                if (typeof map.plugin.supportsGeocoding === "function") {
                    log("Geocoding supported: " + map.plugin.supportsGeocoding())
                }
            } else {
                log("Map or plugin not available")
            }
            markers = [];
            mapItems = [];
            
            // If we have initial coordinates, move to them
            if (hasInitialCoordinates) {
                log("Moving to initial location: " + initialLat + ", " + initialLon)
                findAndMarkLocation(initialLat, initialLon)
            }
            
        } catch (e) {
            console.log("Error in Component.onCompleted:", e)
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Plus) {
            view.map.zoomLevel++;
        } else if (event.key === Qt.Key_Minus) {
            view.map.zoomLevel--;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                   event.key === Qt.Key_Up   || event.key === Qt.Key_Down) {
            var dx = 0;
            var dy = 0;

            switch (event.key) {

            case Qt.Key_Left: dx = view.map.width / 4; break;
            case Qt.Key_Right: dx = -view.map.width / 4; break;
            case Qt.Key_Up: dy = view.map.height / 4; break;
            case Qt.Key_Down: dy = -view.map.height / 4; break;

            }

            var mapCenterPoint = Qt.point(view.map.width / 2.0 - dx, view.map.height / 2.0 - dy);
            view.map.center = view.map.toCoordinate(mapCenterPoint);
        }
    }

    PositionSource{
        id: positionSource
        active: followme

        onPositionChanged: {
            view.map.center = positionSource.position.coordinate
        }
    }

    MapQuickItem {
        id: mePoisition
        parent: view.map
        sourceItem: Rectangle { width: 14; height: 14; color: "#251ee4"; border.width: 2; border.color: "white"; smooth: true; radius: 7 }
        coordinate: positionSource.position.coordinate
        opacity: 1.0
        anchorPoint: Qt.point(sourceItem.width/2, sourceItem.height/2)
        visible: followme
    }
    MapQuickItem {
        parent: view.map
        sourceItem: Text{
            text: qsTr("You're here!")
            color:"#242424"
            font.bold: true
            styleColor: "#ECECEC"
            style: Text.Outline
        }
        coordinate: positionSource.position.coordinate
        anchorPoint: Qt.point(-mePoisition.sourceItem.width * 0.5, mePoisition.sourceItem.height * 1.5)
        visible: followme
    }


    MapQuickItem {
        id: poiTheQtComapny
        parent: view.map
        sourceItem: Rectangle { width: 14; height: 14; color: "#e41e25"; border.width: 2; border.color: "white"; smooth: true; radius: 7 }
        coordinate {
            latitude: 59.9485
            longitude: 10.7686
        }
        opacity: 1.0
        anchorPoint: Qt.point(sourceItem.width/2, sourceItem.height/2)
    }

    MapQuickItem {
        parent: view.map
        sourceItem: Text{
            text: "The Qt Company"
            color:"#242424"
            font.bold: true
            styleColor: "#ECECEC"
            style: Text.Outline
        }
        coordinate: poiTheQtComapny.coordinate
        anchorPoint: Qt.point(-poiTheQtComapny.sourceItem.width * 0.5, poiTheQtComapny.sourceItem.height * 1.5)
    }

    MapSliders {
        id: sliders
        z: view.map.z + 3
        mapSource: map
        edge: Qt.LeftEdge
    }

    Item {
        id: scale
        z: view.map.z + 3
        visible: scaleText.text !== "0 m"
        anchors.bottom: parent.bottom;
        anchors.right: parent.right
        anchors.margins: 20
        height: scaleText.height * 2
        width: scaleImage.width

        Image {
            id: scaleImageLeft
            source: "../resources/scale_end.png"
            anchors.bottom: parent.bottom
            anchors.right: scaleImage.left
        }
        Image {
            id: scaleImage
            source: "../resources/scale.png"
            anchors.bottom: parent.bottom
            anchors.right: scaleImageRight.left
        }
        Image {
            id: scaleImageRight
            source: "../resources/scale_end.png"
            anchors.bottom: parent.bottom
            anchors.right: parent.right
        }
        Label {
            id: scaleText
            color: "#004EAE"
            anchors.centerIn: parent
            text: "0 m"
        }
        Component.onCompleted: {
            view.calculateScale();
        }
    }

    //! [routemodel0]
    RouteModel {
        id: routeModel
        plugin : view.map.plugin
        query:  RouteQuery {
            id: routeQuery
        }
        onStatusChanged: {
            if (status == RouteModel.Ready) {
                switch (count) {
                case 0:
                    // technically not an error
                    view.routeError()
                    break
                case 1:
                    view.showRouteList()
                    break
                }
            } else if (status == RouteModel.Error) {
                view.routeError()
            }
        }
    }
    //! [routemodel0]

    //! [routedelegate0]
    Component {
        id: routeDelegate

        MapRoute {
            id: route
            route: routeData
            line.color: "#46a2da"
            line.width: 5
            smooth: true
            opacity: 0.8
     //! [routedelegate0]
            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onLongPressed: showRouteMenu(view.map.toCoordinate(tapHandler.point.position))
                onSingleTapped: (eventPoint, button) => {
                    if (button === Qt.RightButton)
                        showRouteMenu(view.map.toCoordinate(tapHandler.point.position))
                }
            }
        }
    }

    //! [geocodemodel0]
    GeocodeModel {
        id: geocodeModel
        plugin: view.map.plugin
        
        onStatusChanged: {
            var statusText = ""
            switch(status) {
                case GeocodeModel.Null: statusText = "Null"; break;
                case GeocodeModel.Ready: statusText = "Ready"; break;
                case GeocodeModel.Loading: statusText = "Loading"; break;
                case GeocodeModel.Error: statusText = "Error"; break;
                default: statusText = "Unknown";
            }
            log("Geocode status changed to: " + statusText + " (" + status + ")")
            
            if ((status == GeocodeModel.Ready) || (status == GeocodeModel.Error))
                view.geocodeFinished()
        }
        
        onLocationsChanged: {
            log("Geocode locations changed. Count: " + count)
            if (count === 1) {
                var coordinate = get(0).coordinate
                log("Found location:")
                log("  - Latitude: " + coordinate.latitude)
                log("  - Longitude: " + coordinate.longitude)
                log("  - Address: " + get(0).address.text)
                view.map.center = coordinate
                view.map.zoomLevel = 15
                locationMarker.coordinate = coordinate
                locationMarker.visible = true
            } else if (count > 1) {
                log("Multiple locations found: " + count)
            } else {
                log("No locations found")
            }
        }
        
        onErrorChanged: {
            if (error !== GeocodeModel.NoError) {
                log("Geocoding error occurred:")
                log("  - Error code: " + error)
                log("  - Error string: " + errorString)
                log("  - Current query: " + query)
            }
        }
    }
    //! [geocodemodel0]

    //! [pointdel0]
    Component {
        id: pointDelegate

        MapQuickItem {
            id: point
            parent: view.map
            coordinate: locationData.coordinate

            sourceItem: Image {
                id: pointMarker
                source: "../resources/marker_blue.png"
                //! [pointdel0]

                Text{
                    id: pointText
                    anchors.bottom: pointMarker.top
                    anchors.horizontalCenter: pointMarker.horizontalCenter
                    text: locationData.address.street + ", " + locationData.address.city
                    color:"#242424"
                    font.bold: true
                    styleColor: "#ECECEC"
                    style: Text.Outline
                }

            }
            smooth: true
            autoFadeIn: false
            anchorPoint.x: pointMarker.width/4
            anchorPoint.y: pointMarker.height

            TapHandler {
                onLongPressed: showPointMenu(point.coordinate)
            //! [pointdel1]
            }
        }
    }
    //! [pointdel1]

    //! [routeview0]
    MapItemView {
        parent: view.map
        model: routeModel
        delegate: routeDelegate
    //! [routeview0]
        autoFitViewport: true
    }

    //! [geocodeview]
    MapItemView {
        parent: view.map
        model: geocodeModel
        delegate: pointDelegate
    }
    //! [geocodeview]

    Timer {
        id: scaleTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: view.calculateScale()
    }

    // Location picker marker with address label
    MapQuickItem {
        id: locationMarker
        parent: view.map
        visible: false
        anchorPoint.x: sourceItem.width/2
        anchorPoint.y: sourceItem.height
        property string currentAddress: ""  // Add property to store current address
        
        sourceItem: Column {
            spacing: 4
            
            // Marker
            Item {
                width: 24
                height: 24
                anchors.horizontalCenter: parent.horizontalCenter
                
                // Main circle
                Rectangle {
                    width: parent.width
                    height: parent.height
                    radius: width/2
                    color: "#007AFF"  // Blue color
                    border.width: 2
                    border.color: "white"
                    
                    // Inner dot
                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: "white"
                        anchors.centerIn: parent
                    }
                }
                
                // Bottom triangle for pointer
                Rectangle {
                    width: 12
                    height: 12
                    color: "#007AFF"
                    rotation: 45
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.bottom
                        verticalCenterOffset: -4
                    }
                }
            }
            
            // Address label
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#007AFF"
                radius: 4
                width: addressText.width + 16
                height: addressText.height + 8
                visible: locationMarker.currentAddress !== ""
                
                Text {
                    id: addressText
                    anchors.centerIn: parent
                    text: locationMarker.currentAddress
                    color: "white"
                    font.pixelSize: 12
                    width: Math.min(implicitWidth, 200)  // Max width
                    elide: Text.ElideMiddle  // Add ellipsis if too long
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // Modify the select button section
    Rectangle {
        id: selectButton
        z: view.map.z + 3
        width: 120
        height: 40
        color: locationMarker.visible ? "#007AFF" : "#CCCCCC"  // Gray when disabled
        radius: 5
        visible: true  // Always visible
        anchors {
            bottom: parent.bottom
            right: parent.right
            margins: 20
        }

        // Progress dots
        Row {
            id: progressDots
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: -10
            }
            spacing: 4
            visible: false

            Repeater {
                model: 3
                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: "#007AFF"
                    opacity: 0

                    SequentialAnimation on opacity {
                        id: dotAnimation
                        running: progressDots.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 0
                            to: 1
                            duration: 500
                            easing.type: Easing.InOutQuad
                        }
                        PauseAnimation {
                            duration: index * 200
                        }
                        NumberAnimation {
                            from: 1
                            to: 0
                            duration: 500
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: "Choose Location"
            color: locationMarker.visible ? "white" : "#666666"  // Darker when disabled
            font.pixelSize: 14
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                try {
                    if (locationMarker.visible && locationMarker.coordinate) {
                        log("Choose Location button clicked")
                        
                        // Show progress dots
                        progressDots.visible = true
                        
                        // Send coordinates and address to handler
                        if (locationHandler) {
                            locationHandler.handle_click(
                                locationMarker.coordinate.latitude,
                                locationMarker.coordinate.longitude,
                                locationMarker.currentAddress  // Add address to handler
                            )
                            log("Location sent: " + locationMarker.coordinate.latitude + 
                                ", " + locationMarker.coordinate.longitude + 
                                " with address: " + locationMarker.currentAddress)
                            
                            // Wait a moment then hide marker only
                            closeTimer.start()
                        }
                    }
                } catch (e) {
                    console.log("Error in select button click:", e)
                }
            }
        }
    }

    // Update the close timer
    Timer {
        id: closeTimer
        interval: 500
        repeat: false
        onTriggered: {
            try {
                log("Close timer triggered, cleaning up")
                // Only hide marker and progress dots
                locationMarker.visible = false
                progressDots.visible = false
            } catch (e) {
                console.log("Error in close timer:", e)
            }
        }
    }

    // Update TapHandler to also get address when clicking
    TapHandler {
        id: tapHandler
        property variant lastCoordinate
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressedChanged: (eventPoint, button) => {
            if (pressed) {
                lastCoordinate = view.map.toCoordinate(tapHandler.point.position)
                
                // Update marker position and make it visible
                locationMarker.coordinate = lastCoordinate
                locationMarker.visible = true
                
                // Get address for the clicked location
                var lat = lastCoordinate.latitude
                var lon = lastCoordinate.longitude
                
                geocodeModel.query = lat + "," + lon
                geocodeModel.update()
                
                log("Map clicked at: " + lat + ", " + lon)
                startProgress()
            }
        }

        onSingleTapped: (eventPoint, button) => {
                if (button === Qt.RightButton) {
                    showMainMenu(lastCoordinate)
                }
        }

        onDoubleTapped: (eventPoint, button) => {
            var preZoomPoint = view.map.toCoordinate(eventPoint.position);
            if (button === Qt.LeftButton) {
                view.map.zoomLevel = Math.floor(view.map.zoomLevel + 1)
            } else if (button === Qt.RightButton) {
                view.map.zoomLevel = Math.floor(view.map.zoomLevel - 1)
            }
            var postZoomPoint = view.map.toCoordinate(eventPoint.position);
            var dx = postZoomPoint.latitude - preZoomPoint.latitude;
            var dy = postZoomPoint.longitude - preZoomPoint.longitude;

            view.map.center = QtPositioning.coordinate(view.map.center.latitude - dx,
                                                       view.map.center.longitude - dy);
        }
    }

    // Modify the suggestion model
    GeocodeModel {
        id: suggestionModel
        plugin: view.map.plugin
        autoUpdate: false
        limit: 5

        onStatusChanged: {
            try {
                var statusText = ""
                switch(status) {
                    case GeocodeModel.Ready: statusText = "Ready"; break;
                    case GeocodeModel.Loading: statusText = "Loading"; break;
                    case GeocodeModel.Error: statusText = "Error"; break;
                    default: statusText = "Unknown";
                }
                log("Suggestion model status: " + statusText)
            } catch (e) {
                console.log("Error in status changed:", e)
            }
        }

        onLocationsChanged: {
            try {
                log("Suggestions received. Count: " + count)
                if (count > 0) {
                    for (var i = 0; i < Math.min(count, 5); i++) {
                        var location = get(i)
                        if (location && location.address) {
                            log("Suggestion " + (i + 1) + ": " + 
                                (location.address.text || "No address text"))
                        }
                    }
                }
                suggestionList.visible = count > 0
            } catch (e) {
                console.log("Error in locations changed:", e)
            }
        }

        onErrorChanged: {
            if (error !== GeocodeModel.NoError) {
                log("Suggestion error: " + errorString)
            }
        }
    }

    // Modify the Timer for suggestions
    Timer {
        id: suggestionTimer
        interval: 2000
        repeat: false
        onTriggered: {
            try {
                if (searchInput.text.length > 2) {
                    log("Starting suggestion search for: " + searchInput.text)
                    suggestionModel.query = searchInput.text
                    suggestionModel.update()
                }
            } catch (e) {
                console.log("Error in suggestion timer:", e)
            }
        }
    }

    // Add this somewhere visible in your MapView
    Rectangle {
        id: debugOutput
        z: view.map.z + 4
        width: parent.width * 0.8
        height: 100  // Fixed height instead of dynamic
        color: "#80000000"
        visible: config.enableDebugOutput
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            margins: 10
        }

        Text {
            id: debugText
            anchors.fill: parent
            anchors.margins: 10
            color: "white"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            text: ""
        }

        function addLog(message) {
            try {
                var currentText = debugText.text
                debugText.text = new Date().toLocaleTimeString() + ": " + message + "\n" + currentText
                // Keep only last 5 lines
                var lines = debugText.text.split('\n').slice(0, 5)
                debugText.text = lines.join('\n')
            } catch (e) {
                console.log("Error in addLog:", e)
            }
        }
    }

    // Add this near the search button
    Rectangle {
        id: testLogButton
        z: view.map.z + 4
        width: 100
        height: 40
        color: "#007AFF"
        radius: 5
        anchors {
            top: parent.top
            right: parent.right
            margins: 10
        }

        Text {
            anchors.centerIn: parent
            text: "Test Log"
            color: "white"
        }

        TapHandler {
            onTapped: {
                log("Test log button clicked!")
                console.log("Direct console.log test")
                if (typeof logger !== "undefined") {
                    logger.log("Test via logger object")
                }
            }
        }
    }

    // Add a debug controls button (only visible in development)
    Rectangle {
        id: debugControls
        z: view.map.z + 4
        width: 40
        height: 40
        color: "#007AFF"
        radius: 20
        visible: Qt.application.arguments.indexOf("--debug") !== -1  // Only show in debug mode
        anchors {
            top: testLogButton.bottom
            right: parent.right
            margins: 10
        }

        Text {
            anchors.centerIn: parent
            text: "��"
            color: "white"
            font.pixelSize: 20
        }

        TapHandler {
            onTapped: debugMenu.visible = !debugMenu.visible
        }

        // Debug menu popup
        Rectangle {
            id: debugMenu
            width: 200
            height: column.height + 20
            color: "#ffffff"
            radius: 5
            visible: false
            anchors {
                right: parent.left
                top: parent.top
                margins: 10
            }

            Column {
                id: column
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 10

                Text {
                    text: "Debug Settings"
                    font.bold: true
                }

                CheckBox {
                    text: "Show Debug Output"
                    checked: config.enableDebugOutput
                    enabled: false  // Read-only since it's a readonly property
                }

                CheckBox {
                    text: "Console Logs"
                    checked: config.enableConsoleLog
                    enabled: false
                }

                CheckBox {
                    text: "Python Logs"
                    checked: config.enablePythonLog
                    enabled: false
                }

                CheckBox {
                    text: "Search Logs"
                    checked: config.enableSearchLogs
                    enabled: false
                }

                CheckBox {
                    text: "Map Logs"
                    checked: config.enableMapLogs
                    enabled: false
                }
            }
        }
    }

    // Progress bar for location selection
    Rectangle {
        id: progressBar
        z: view.map.z + 3
        width: parent.width
        height: 3
        color: "transparent"
        visible: false
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        Rectangle {
            id: progressIndicator
            height: parent.height
            width: 0
            color: "#007AFF"
        }

        // Progress animation
        PropertyAnimation {
            id: progressAnimation
            target: progressIndicator
            property: "width"
            from: 0
            to: progressBar.width
            duration: 1000
            easing.type: Easing.InOutQuad
        }

        // Completion animation
        PropertyAnimation {
            id: completionAnimation
            target: progressIndicator
            property: "width"
            duration: 300
            easing.type: Easing.InOutQuad
            onFinished: {
                if (progressIndicator.width === progressBar.width) {
                    progressBar.visible = false
                    progressIndicator.width = 0
                }
            }
        }
    }

    // Add these functions to the MapView:
    function startProgress() {
        progressBar.visible = true
        progressAnimation.start()
    }

    function completeProgress() {
        completionAnimation.from = progressIndicator.width
        completionAnimation.to = progressBar.width
        completionAnimation.start()
    }

    // Add this function to set initial marker
    function setInitialMarker(lat, lon) {
        try {
            log("Setting initial marker at: " + lat + ", " + lon)
            
            // Set map center to the coordinates
            view.map.center = QtPositioning.coordinate(lat, lon)
            view.map.zoomLevel = 15  // Set appropriate zoom level
            
            // Show marker at the coordinates
            locationMarker.coordinate = QtPositioning.coordinate(lat, lon)
            locationMarker.visible = true
            
        } catch (e) {
            console.log("Error setting initial marker:", e)
        }
    }

    // Update the findAndMarkLocation function
    function findAndMarkLocation(lat, lon) {
        try {
            log("Finding location at: " + lat + ", " + lon)
            
            // Set map center to the coordinates
            view.map.center = QtPositioning.coordinate(lat, lon)
            view.map.zoomLevel = 15
            
            // Show marker at the coordinates
            locationMarker.coordinate = QtPositioning.coordinate(lat, lon)
            locationMarker.visible = true
            
            // Use geocoding to find address
            var searchQuery = lat + "," + lon
            log("Searching for address at: " + searchQuery)
            
            geocodeModel.query = searchQuery
            geocodeModel.update()
            
            // Handle the geocoding result
            geocodeModel.statusChanged.connect(function() {
                if (geocodeModel.status === GeocodeModel.Ready) {
                    if (geocodeModel.count > 0) {
                        var location = geocodeModel.get(0)
                        if (location && location.address) {
                            var address = location.address
                            var addressText = ""
                            
                            // Build full address string
                            if (address.street) addressText += address.street
                            if (address.district) {
                                if (addressText) addressText += ", "
                                addressText += address.district
                            }
                            if (address.city) {
                                if (addressText) addressText += ", "
                                addressText += address.city
                            }
                            if (address.country) {
                                if (addressText) addressText += ", "
                                addressText += address.country
                            }
                            
                            log("Found address: " + addressText)
                            locationMarker.currentAddress = addressText
                            
                            // Emit both address and coordinates
                            suggestionSelected(addressText, lat, lon)
                        }
                    }
                }
            })
            
        } catch (e) {
            console.log("Error finding location:", e)
        }
    }

    // Add function to search by address
    function searchAddress(address) {
        try {
            log("Searching for address: " + address)
            geocodeModel.query = address
            geocodeModel.update()
        } catch (e) {
            console.log("Error searching address:", e)
        }
    }
}
//! [end]
