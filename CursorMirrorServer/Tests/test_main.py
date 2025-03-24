import pytest
from unittest.mock import Mock, patch
import asyncio
from cursor_mirror_server.main import app, start_server, stop_server
from cursor_mirror_server.connection_manager import ConnectionManager
from cursor_mirror_server.hls_streaming import HLSStreamManager
from cursor_mirror_server.qos_optimization import QoSOptimizer
from cursor_mirror_server.cloudkit_integration import CloudKitService

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
def mock_cloudkit_service():
    return Mock(spec=CloudKitService)

@pytest.fixture
def mock_services(mock_connection_manager, mock_hls_stream, mock_qos_optimizer, mock_cloudkit_service):
    return {
        'connection_manager': mock_connection_manager,
        'hls_stream': mock_hls_stream,
        'qos_optimizer': mock_qos_optimizer,
        'cloudkit_service': mock_cloudkit_service
    }

class TestMainApplication:
    def test_app_initialization(self, mock_services):
        # Given
        with patch('cursor_mirror_server.main.connection_manager', mock_services['connection_manager']), \
             patch('cursor_mirror_server.main.hls_stream', mock_services['hls_stream']), \
             patch('cursor_mirror_server.main.qos_optimizer', mock_services['qos_optimizer']), \
             patch('cursor_mirror_server.main.cloudkit_service', mock_services['cloudkit_service']):
            
            # Then
            assert app.title == "Cursor Mirror Server"
            assert app.version == "1.0.0"
            assert app.description == "Server for Cursor Mirror application"

    @pytest.mark.asyncio
    async def test_start_server(self, mock_services):
        # Given
        host = "127.0.0.1"
        port = 8000
        
        # When
        server = await start_server(host, port)
        
        # Then
        assert server is not None
        assert server.host == host
        assert server.port == port

    @pytest.mark.asyncio
    async def test_stop_server(self, mock_services):
        # Given
        server = Mock()
        
        # When
        await stop_server(server)
        
        # Then
        server.shutdown.assert_called_once()

    def test_health_check_endpoint(self, mock_services):
        # Given
        with patch('cursor_mirror_server.main.connection_manager', mock_services['connection_manager']), \
             patch('cursor_mirror_server.main.hls_stream', mock_services['hls_stream']), \
             patch('cursor_mirror_server.main.qos_optimizer', mock_services['qos_optimizer']), \
             patch('cursor_mirror_server.main.cloudkit_service', mock_services['cloudkit_service']):
            
            # When
            response = app.get("/health")
            
            # Then
            assert response.status_code == 200
            assert response.json() == {"status": "healthy"}

    def test_connection_endpoints(self, mock_services):
        # Given
        with patch('cursor_mirror_server.main.connection_manager', mock_services['connection_manager']), \
             patch('cursor_mirror_server.main.hls_stream', mock_services['hls_stream']), \
             patch('cursor_mirror_server.main.qos_optimizer', mock_services['qos_optimizer']), \
             patch('cursor_mirror_server.main.cloudkit_service', mock_services['cloudkit_service']):
            
            # When
            init_response = app.post(
                "/connection/initialize",
                json={"deviceId": "test-id", "deviceName": "Test Device"}
            )
            connect_response = app.post("/connection/connect")
            disconnect_response = app.post("/connection/disconnect")
            heartbeat_response = app.post("/connection/heartbeat")
            status_response = app.get("/connection/status")
            
            # Then
            assert init_response.status_code == 200
            assert connect_response.status_code == 200
            assert disconnect_response.status_code == 200
            assert heartbeat_response.status_code == 200
            assert status_response.status_code == 200

    def test_stream_endpoints(self, mock_services):
        # Given
        with patch('cursor_mirror_server.main.connection_manager', mock_services['connection_manager']), \
             patch('cursor_mirror_server.main.hls_stream', mock_services['hls_stream']), \
             patch('cursor_mirror_server.main.qos_optimizer', mock_services['qos_optimizer']), \
             patch('cursor_mirror_server.main.cloudkit_service', mock_services['cloudkit_service']):
            
            # When
            url_response = app.get("/stream/url")
            stats_response = app.get("/stream/stats")
            
            # Then
            assert url_response.status_code == 200
            assert stats_response.status_code == 200

    def test_optimization_endpoints(self, mock_services):
        # Given
        with patch('cursor_mirror_server.main.connection_manager', mock_services['connection_manager']), \
             patch('cursor_mirror_server.main.hls_stream', mock_services['hls_stream']), \
             patch('cursor_mirror_server.main.qos_optimizer', mock_services['qos_optimizer']), \
             patch('cursor_mirror_server.main.cloudkit_service', mock_services['cloudkit_service']):
            
            # When
            stats_response = app.get("/optimization/stats")
            
            # Then
            assert stats_response.status_code == 200

    def test_error_handling(self, mock_services):
        # Given
        mock_services['connection_manager'].initialize_connection.side_effect = Exception("Test error")
        
        with patch('cursor_mirror_server.main.connection_manager', mock_services['connection_manager']), \
             patch('cursor_mirror_server.main.hls_stream', mock_services['hls_stream']), \
             patch('cursor_mirror_server.main.qos_optimizer', mock_services['qos_optimizer']), \
             patch('cursor_mirror_server.main.cloudkit_service', mock_services['cloudkit_service']):
            
            # When
            response = app.post(
                "/connection/initialize",
                json={"deviceId": "test-id", "deviceName": "Test Device"}
            )
            
            # Then
            assert response.status_code == 500
            assert response.json() == {"error": "Test error"}

    def test_invalid_payload(self, mock_services):
        # Given
        with patch('cursor_mirror_server.main.connection_manager', mock_services['connection_manager']), \
             patch('cursor_mirror_server.main.hls_stream', mock_services['hls_stream']), \
             patch('cursor_mirror_server.main.qos_optimizer', mock_services['qos_optimizer']), \
             patch('cursor_mirror_server.main.cloudkit_service', mock_services['cloudkit_service']):
            
            # When
            response = app.post(
                "/connection/initialize",
                json={"invalid": "payload"}
            )
            
            # Then
            assert response.status_code == 422

    def test_not_connected_error(self, mock_services):
        # Given
        mock_services['connection_manager'].is_connected = False
        
        with patch('cursor_mirror_server.main.connection_manager', mock_services['connection_manager']), \
             patch('cursor_mirror_server.main.hls_stream', mock_services['hls_stream']), \
             patch('cursor_mirror_server.main.qos_optimizer', mock_services['qos_optimizer']), \
             patch('cursor_mirror_server.main.cloudkit_service', mock_services['cloudkit_service']):
            
            # When
            response = app.get("/stream/url")
            
            # Then
            assert response.status_code == 400
            assert response.json() == {"error": "Not connected"} 