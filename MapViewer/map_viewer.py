# Copyright (C) 2023 The Qt Company Ltd.
# SPDX-License-Identifier: LicenseRef-Qt-Commercial OR BSD-3-Clause
from __future__ import annotations

"""PySide6 port of the location/mapviewer example from Qt v6.x"""

import os
import sys
from pathlib import Path
import logging

from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtGui import QGuiApplication
from PySide6.QtNetwork import QSslSocket
from PySide6.QtCore import (QCoreApplication, QMetaObject, Q_ARG, Signal, QObject,
                           Slot, QTimer)
from PySide6.QtWidgets import QApplication

HELP = """Usage:
plugin.<parameter_name> <parameter_value> - Sets parameter = value for plugin"""

# Set up basic logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(message)s',  # Simplified format
    stream=sys.stdout  # Use stdout
)
logger = logging.getLogger(__name__)

class LoggingHelper(QObject):
    @Slot(str)
    def log(self, message):
        try:
            print(f"QML: {message}", flush=True)
        except Exception as e:
            print(f"Error in logging: {e}", flush=True)


class LocationHandler(QObject):
    location_selected = Signal(float, float, str)
    
    def __init__(self):
        super().__init__()
        self.timer = QTimer()
        self.timer.setSingleShot(True)
        self.timer.setInterval(2000)  # 2 seconds
        self.timer.timeout.connect(self.emit_location)
        self.pending_location = None
        self.last_location = None  # Add this to store the last selected location

    @Slot(float, float, str)
    def handle_click(self, lat, lon, address):
        """Handle click with coordinates and address"""
        print(f"Location handler received: {lat}, {lon}, {address}")
        self.location_selected.emit(lat, lon, address)

    def emit_location(self):
        if self.pending_location:
            lat, lon = self.pending_location
            self.last_location = (lat, lon)  # Store the location
            print(f"Selected location: {lat}, {lon}", flush=True)
            self.location_selected.emit(lat, lon, "")
            self.pending_location = None


class MapViewer:
    def __init__(self, existing_app=None):
        # Use existing application if provided, otherwise create new one
        self.application = existing_app or QGuiApplication.instance() or QGuiApplication([])
        QCoreApplication.setApplicationName("QtLocation Mapviewer example")
        
        # Initialize QML engine
        self.engine = QQmlApplicationEngine()
        
        # Set up components
        self.logging_helper = LoggingHelper()
        self.location_handler = LocationHandler()
        
        # Initialize UI
        self.setup_ui()
        self.window = None

    def setup_ui(self):
        try:
            # Set context properties
            self.engine.rootContext().setContextProperty("logger", self.logging_helper)
            self.engine.rootContext().setContextProperty("supportsSsl", QSslSocket.supportsSsl())
            self.engine.rootContext().setContextProperty("locationHandler", self.location_handler)
            
            # Get the absolute path to the QML files directory
            qml_dir = os.path.dirname(os.path.abspath(__file__))
            
            # Add import paths for QML modules
            self.engine.addImportPath(os.path.dirname(qml_dir))  # For project root
            self.engine.addImportPath(qml_dir)  # For MapViewer directory
            
            # Load the main QML file from the map subdirectory
            qml_file = os.path.join(qml_dir, "map", "Main.qml")
            if not os.path.exists(qml_file):
                raise FileNotFoundError(
                    f"Could not find Main.qml at {qml_file}\n"
                    f"Please ensure the file exists and follows the structure:\n"
                    f"MapViewer/\n"
                    f"  └── map/\n"
                    f"      └── Main.qml"
                )
                
            print(f"Loading QML from: {qml_file}")  # Debug info
            self.engine.load(qml_file)
            
            # Store the window reference
            items = self.engine.rootObjects()
            if items:
                self.window = items[0]
            else:
                raise RuntimeError(
                    "Failed to create window from QML. "
                    "Check the QML file for errors and required imports."
                )

        except Exception as e:
            print(f"Error setting up UI: {e}", flush=True)
            raise

    def parse_args(self, args):
        parameters = {}
        while args:
            param = args[0]
            args = args[1:]
            if param.startswith("--plugin."):
                param = param[9:]
                if not args or args[0].startswith("--"):
                    parameters[param] = True
                else:
                    value = args[0]
                    args = args[1:]
                    if value in ("true", "on", "enabled"):
                        parameters[param] = True
                    elif value in ("false", "off", "disable"):
                        parameters[param] = False
                    else:
                        parameters[param] = value
        return parameters

    def run(self, args=None):
        try:
            if args is None:
                args = sys.argv[1:]

            # Check for help command
            if "--help" in args:
                print("QtLocation Mapviewer example\n\nUsage:\nplugin.<parameter_name> <parameter_value> - Sets parameter = value for plugin")
                return 0

            # Parse and apply parameters
            parameters = self.parse_args(args)
            if not parameters.get("osm.useragent"):
                parameters["osm.useragent"] = "QtLocation Mapviewer example"

            # Initialize providers if root objects exist
            items = self.engine.rootObjects()
            if not items:
                return -1

            QMetaObject.invokeMethod(items[0], "initializeProviders",
                                   Q_ARG("QVariant", parameters))

            # Run the application
            return self.application.exec()

        except Exception as e:
            print(f"Error during execution: {e}", flush=True)
            return 1

    def run_non_blocking(self):
        """Run the map viewer without blocking"""
        try:
            # Parse and apply parameters
            parameters = {"osm.useragent": "QtLocation Mapviewer example"}

            # Initialize providers if root objects exist
            items = self.engine.rootObjects()
            if not items:
                return False

            QMetaObject.invokeMethod(items[0], "initializeProviders",
                                   Q_ARG("QVariant", parameters))
            
            return True
            
        except Exception as e:
            print(f"Error during non-blocking execution: {e}", flush=True)
            return False

    def cleanup(self):
        try:
            if self.window:
                self.window.hide()  # Hide the window first
                self.window.destroy()  # Destroy the window
                self.window = None
            if hasattr(self, 'engine'):
                self.engine.deleteLater()  # Use deleteLater instead of direct deletion
                del self.engine
        except Exception as e:
            print(f"Error in cleanup: {e}", flush=True)


def main():
    viewer = MapViewer()
    try:
        exit_code = viewer.run()
        viewer.cleanup()
        return exit_code
    except Exception as e:
        print(f"Error in main: {e}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
