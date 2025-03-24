import pytest
from unittest.mock import Mock, patch
from fastapi.testclient import TestClient
from cursor_mirror_server.main import app
from cursor_mirror_server.connection_manager import ConnectionManager
from cursor_mirror_server.cloudkit_integration import CloudKitService

@pytest.fixture
def mock_cloudkit_service():
    return Mock(spec=CloudKitService)

@pytest.fixture
def mock_connection_manager(mock_cloudkit_service):
    return Mock(spec=ConnectionManager)

@pytest.fixture
def client(mock_connection_manager):
    with patch('cursor_mirror_server.main.connection_manager', mock_connection_manager):
        return TestClient(app)

class TestHTTPEndpoints:
    def test_health_check(self, client):
        # When
        response = client.get("/health")
        
        # Then
        assert response.status_code == 200
        assert response.json() == {"status": "healthy"}

    def test_initialize_connection(self, client, mock_connection_manager):
        # Given
        device_id = "test-device-id"
        device_name = "Test Device"
        
        # When
        response = client.post(
            "/connection/initialize",
            json={"deviceId": device_id, "deviceName": device_name}
        )
        
        # Then
        assert response.status_code == 200
        mock_connection_manager.initialize_connection.assert_called_once_with(
            device_id, device_name
        )
        assert response.json() == {"status": "success"}

    def test_initialize_connection_invalid_payload(self, client):
        # When
        response = client.post(
            "/connection/initialize",
            json={"invalid": "payload"}
        )
        
        # Then
        assert response.status_code == 422

    def test_handle_client_connection(self, client, mock_connection_manager):
        # When
        response = client.post("/connection/connect")
        
        # Then
        assert response.status_code == 200
        mock_connection_manager.handle_client_connection.assert_called_once()
        assert response.json() == {"status": "success"}

    def test_handle_client_disconnection(self, client, mock_connection_manager):
        # When
        response = client.post("/connection/disconnect")
        
        # Then
        assert response.status_code == 200
        mock_connection_manager.handle_client_disconnection.assert_called_once()
        assert response.json() == {"status": "success"}

    def test_update_heartbeat(self, client, mock_connection_manager):
        # When
        response = client.post("/connection/heartbeat")
        
        # Then
        assert response.status_code == 200
        mock_connection_manager.update_heartbeat.assert_called_once()
        assert response.json() == {"status": "success"}

    def test_get_connection_status(self, client, mock_connection_manager):
        # Given
        mock_status = {
            "deviceId": "test-id",
            "deviceName": "Test Device",
            "isConnected": True,
            "lastHeartbeat": "2024-03-20T12:00:00"
        }
        mock_connection_manager.get_connection_status.return_value = mock_status
        
        # When
        response = client.get("/connection/status")
        
        # Then
        assert response.status_code == 200
        mock_connection_manager.get_connection_status.assert_called_once()
        assert response.json() == mock_status

    def test_error_handling(self, client, mock_connection_manager):
        # Given
        mock_connection_manager.initialize_connection.side_effect = Exception("Test error")
        
        # When
        response = client.post(
            "/connection/initialize",
            json={"deviceId": "test-id", "deviceName": "Test Device"}
        )
        
        # Then
        assert response.status_code == 500
        assert response.json() == {"error": "Test error"}

    def test_get_stream_url(self, client, mock_connection_manager):
        # Given
        mock_connection_manager.is_connected = True
        
        # When
        response = client.get("/stream/url")
        
        # Then
        assert response.status_code == 200
        assert "url" in response.json()
        assert response.json()["url"].startswith("http://")

    def test_get_stream_url_not_connected(self, client, mock_connection_manager):
        # Given
        mock_connection_manager.is_connected = False
        
        # When
        response = client.get("/stream/url")
        
        # Then
        assert response.status_code == 400
        assert response.json() == {"error": "Not connected"} 