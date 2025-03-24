import pytest
from unittest.mock import Mock, patch
from fastapi.testclient import TestClient
from cursor_mirror_server.main import app
from cursor_mirror_server.connection_manager import ConnectionManager
from cursor_mirror_server.hls_streaming import HLSStreamManager
from cursor_mirror_server.qos_optimization import QoSOptimizer

@pytest.fixture
def mock_connection_manager():
    return Mock(spec=ConnectionManager)

@pytest.fixture
def mock_hls_stream():
    return Mock(spec=HLSStreamManager)

@pytest.fixture
def mock_qos_optimizer():
    return Mock(spec=QoSOptimizer)

@pytest.fixture
def client(mock_connection_manager, mock_hls_stream, mock_qos_optimizer):
    with patch('cursor_mirror_server.main.connection_manager', mock_connection_manager), \
         patch('cursor_mirror_server.main.hls_stream', mock_hls_stream), \
         patch('cursor_mirror_server.main.qos_optimizer', mock_qos_optimizer):
        return TestClient(app)

class TestHTTPServer:
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

    def test_get_stream_url(self, client, mock_hls_stream):
        # Given
        mock_hls_stream.get_stream_url.return_value = "http://test.com/stream.m3u8"
        
        # When
        response = client.get("/stream/url")
        
        # Then
        assert response.status_code == 200
        mock_hls_stream.get_stream_url.assert_called_once()
        assert response.json() == {"url": "http://test.com/stream.m3u8"}

    def test_get_stream_stats(self, client, mock_hls_stream):
        # Given
        mock_stats = {
            "fps": 30.0,
            "frame_count": 100,
            "processing_time": 0.016,
            "segment_count": 5
        }
        mock_hls_stream.get_stream_stats.return_value = mock_stats
        
        # When
        response = client.get("/stream/stats")
        
        # Then
        assert response.status_code == 200
        mock_hls_stream.get_stream_stats.assert_called_once()
        assert response.json() == mock_stats

    def test_get_optimization_stats(self, client, mock_qos_optimizer):
        # Given
        mock_stats = {
            "current_fps": 25.0,
            "current_quality": 0.8,
            "current_processing_time": 0.05,
            "current_bandwidth": 5000000,
            "current_latency": 100,
            "optimization_count": 10
        }
        mock_qos_optimizer.get_optimization_stats.return_value = mock_stats
        
        # When
        response = client.get("/optimization/stats")
        
        # Then
        assert response.status_code == 200
        mock_qos_optimizer.get_optimization_stats.assert_called_once()
        assert response.json() == mock_stats

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

    def test_invalid_payload(self, client):
        # When
        response = client.post(
            "/connection/initialize",
            json={"invalid": "payload"}
        )
        
        # Then
        assert response.status_code == 422

    def test_not_connected_error(self, client, mock_connection_manager):
        # Given
        mock_connection_manager.is_connected = False
        
        # When
        response = client.get("/stream/url")
        
        # Then
        assert response.status_code == 400
        assert response.json() == {"error": "Not connected"} 