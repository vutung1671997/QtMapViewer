from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, 
                              QLineEdit, QPushButton, QLabel, QProgressBar)
from PySide6.QtCore import Qt, Slot, QTimer, Signal, QPropertyAnimation, QEasingCurve, QMetaObject, Q_ARG, QObject
from PySide6.QtGui import QDoubleValidator
import sys
from MapViewer.map_viewer import MapViewer

class LocationHandler(QObject):
    location_selected = Signal(float, float, str)  # Add str for address

    @Slot(float, float, str)
    def handle_click(self, lat, lon, address):
        """Handle click with coordinates and address"""
        self.location_selected.emit(lat, lon, address)

class LocationPickerWidget(QWidget):
    # Add signal to notify when location changes
    location_changed = Signal(float, float)
    
    def __init__(self, parent=None, existing_app=None):
        super().__init__(parent)
        self.existing_app = existing_app
        
        # Create layout
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)  # Remove margins for embedding
        
        # Create latitude input
        lat_layout = QHBoxLayout()
        lat_label = QLabel("Latitude:")
        self.lat_input = QLineEdit()
        self.lat_input.setPlaceholderText("Enter latitude")
        # Set default latitude
        self.lat_input.setText("21.02860193565997")
        lat_layout.addWidget(lat_label)
        lat_layout.addWidget(self.lat_input)
        layout.addLayout(lat_layout)
        
        # Create longitude input
        lon_layout = QHBoxLayout()
        lon_label = QLabel("Longitude:")
        self.lon_input = QLineEdit()
        self.lon_input.setPlaceholderText("Enter longitude")
        # Set default longitude
        self.lon_input.setText("105.8357515048705")
        lon_layout.addWidget(lon_label)
        lon_layout.addWidget(self.lon_input)
        layout.addLayout(lon_layout)
        
        # Add address input and label
        address_layout = QHBoxLayout()
        address_label = QLabel("Address:")
        self.address_input = QLineEdit()
        self.address_input.setPlaceholderText("Enter address to search")
        address_layout.addWidget(address_label)
        address_layout.addWidget(self.address_input)
        layout.addLayout(address_layout)
        
        # Add address result label
        self.address_result = QLabel('Found address:')
        self.address_result.setWordWrap(True)
        self.address_result.setAlignment(Qt.AlignCenter)
        self.address_result.setStyleSheet("""
            QLabel {
                color: #007AFF;
                padding: 5px;
                background: #F0F0F0;
                border-radius: 4px;
            }
        """)
        layout.addWidget(self.address_result)
        
        # Create button layout
        button_layout = QHBoxLayout()
        
        self.map_button = QPushButton("Open Map")
        self.map_button.clicked.connect(self.open_map)
        button_layout.addWidget(self.map_button)
        
        self.clear_button = QPushButton("Clear")
        self.clear_button.clicked.connect(self.clear_inputs)
        button_layout.addWidget(self.clear_button)
        
        layout.addLayout(button_layout)
        
        # Initialize map viewer
        self.map_viewer = None
        self.cleanup_timer = QTimer()
        self.cleanup_timer.setSingleShot(True)
        self.cleanup_timer.timeout.connect(self.perform_cleanup)
        
        # Store coordinates
        self.current_lat = 21.02860193565997
        self.current_lon = 105.8357515048705
        self.coordinates_selected = True

        # Add validators for lat/long inputs
        self.lat_input.setValidator(QDoubleValidator(-90.0, 90.0, 6))
        self.lon_input.setValidator(QDoubleValidator(-180.0, 180.0, 6))

    def clear_inputs(self):
        self.lat_input.clear()
        self.lon_input.clear()
        self.address_input.clear()
        self.address_result.setText('Found address:')
        self.address_label.clear()
        self.address_label.setVisible(False)
        self.current_lat = None
        self.current_lon = None
        self.coordinates_selected = False
        self.location_changed.emit(0.0, 0.0)

    def open_map(self):
        try:
            # Create map viewer instance with existing application
            self.map_viewer = MapViewer(existing_app=self.existing_app)
            
            # Connect to location selection signal with address
            if hasattr(self.map_viewer.location_handler, 'location_selected'):
                self.map_viewer.location_handler.location_selected.connect(self.handle_location)
            
            # Connect to suggestion signal
            if self.map_viewer.window:
                self.map_viewer.window.suggestionSelected.connect(self.handle_suggestion)
            
            # Get coordinates from input fields
            lat_text = self.lat_input.text().strip()
            lon_text = self.lon_input.text().strip()
            
            if lat_text and lon_text:
                try:
                    lat = float(lat_text)
                    lon = float(lon_text)
                    
                    # Set initial coordinates in QML
                    if self.map_viewer.engine:
                        context = self.map_viewer.engine.rootContext()
                        context.setContextProperty("initialLat", lat)
                        context.setContextProperty("initialLon", lon)
                        context.setContextProperty("hasInitialCoordinates", True)
                except ValueError:
                    print("Invalid coordinates, using defaults")
                    context.setContextProperty("hasInitialCoordinates", False)
            
            # If we have an address, search for it
            address = self.address_input.text().strip()
            if address:
                QMetaObject.invokeMethod(
                    self.map_viewer.window,
                    "searchAddress",
                    Qt.QueuedConnection,
                    Q_ARG("string", address)
                )
            
            # Run map viewer without blocking
            success = self.map_viewer.run_non_blocking()
            if not success:
                raise Exception("Failed to initialize map viewer")
            
        except Exception as e:
            print(f"Error opening map: {e}")

    def move_to_coordinates(self):
        """Move to the coordinates after map is opened"""
        try:
            lat_text = self.lat_input.text().strip()
            lon_text = self.lon_input.text().strip()
            
            if lat_text and lon_text:
                lat = float(lat_text)
                lon = float(lon_text)
                
                # Validate coordinates
                if -90 <= lat <= 90 and -180 <= lon <= 180:
                    print(f"Moving to location: {lat}, {lon}")
                    
                    if self.map_viewer and self.map_viewer.window:
                        QMetaObject.invokeMethod(
                            self.map_viewer.window,
                            "findAndMarkLocation",
                            Qt.QueuedConnection,
                            Q_ARG("double", lat),
                            Q_ARG("double", lon)
                        )
                        
                        # Store the coordinates
                        self.current_lat = lat
                        self.current_lon = lon
                        self.coordinates_selected = True
                    else:
                        print("Map viewer not ready")
                else:
                    print("Coordinates out of valid range")
            else:
                print("No coordinates provided")
        except ValueError as e:
            print(f"Invalid coordinates in input fields: {e}")
        except Exception as e:
            print(f"Error moving to coordinates: {e}")

    def perform_cleanup(self):
        """Clean up map viewer"""
        try:
            # Update coordinates one last time
            if self.current_lat is not None and self.current_lon is not None:
                self.lat_input.setText(f"{self.current_lat:.6f}")
                self.lon_input.setText(f"{self.current_lon:.6f}")
                self.location_changed.emit(self.current_lat, self.current_lon)
            
            # Clean up map viewer
            if self.map_viewer:
                self.map_viewer.cleanup()
                self.map_viewer = None
            
        except Exception as e:
            print(f"Error in cleanup: {e}")

    @Slot(float, float, str)
    def handle_location(self, lat, lon, address):
        """Handle the selected location with address"""
        try:
            print(f"Received coordinates in widget: {lat}, {lon}")
            print(f"Received address: {address}")
            
            # Store coordinates
            self.current_lat = lat
            self.current_lon = lon
            self.coordinates_selected = True
            
            # Update input fields immediately
            self.lat_input.setText(f"{lat:.6f}")
            self.lon_input.setText(f"{lon:.6f}")
            self.address_result.setText(address)
            
            # Emit the location changed signal
            self.location_changed.emit(lat, lon)
            
            # Start cleanup timer
            self.cleanup_timer.start(1000)
            
        except Exception as e:
            print(f"Error handling location: {e}")

    @Slot(str)
    def handle_address(self, address):
        """Handle the received address"""
        try:
            print(f"Received address: {address}")
            self.address_result.setText(address)
            self.address_result.setVisible(bool(address))
        except Exception as e:
            print(f"Error handling address: {e}")

    @Slot(str, float, float)
    def handle_suggestion(self, address, lat, lon):
        """Handle selected suggestion with address and coordinates"""
        try:
            print(f"Received suggestion: {address} at {lat}, {lon}")
            
            # Update all fields
            self.address_result.setText(address)
            self.lat_input.setText(f"{lat:.6f}")
            self.lon_input.setText(f"{lon:.6f}")
            
            # Store coordinates
            self.current_lat = lat
            self.current_lon = lon
            self.coordinates_selected = True
            
            # Emit location changed
            self.location_changed.emit(lat, lon)
            
        except Exception as e:
            print(f"Error handling suggestion: {e}")

    def get_location(self):
        """Return current location as (latitude, longitude) tuple"""
        if self.coordinates_selected:
            return (self.current_lat, self.current_lon)
        return None

# Example usage in a window
class ExampleWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Location Picker Example")
        layout = QVBoxLayout(self)
        
        # Create and add the location picker widget
        self.location_picker = LocationPickerWidget(
            self, 
            existing_app=QApplication.instance()
        )
        layout.addWidget(self.location_picker)
        
        # Optional: Connect to location changed signal
        self.location_picker.location_changed.connect(self.on_location_changed)
        
        # Add other widgets as needed
        self.result_label = QLabel("Selected location: None")
        layout.addWidget(self.result_label)

    def on_location_changed(self, lat, lon):
        self.result_label.setText(f"Selected location: {lat:.6f}, {lon:.6f}")

if __name__ == "__main__":
    # This is just for testing the widget standalone
    from PySide6.QtWidgets import QApplication
    app = QApplication.instance() or QApplication(sys.argv)
    window = ExampleWindow()
    window.resize(400, 200)
    window.show()
    sys.exit(app.exec()) 