import pytest
from unittest.mock import Mock, patch
from datetime import datetime
from cursor_mirror_server.connection_manager import ConnectionManager
from cursor_mirror_server.cloudkit_integration import CloudKitService

@pytest.fixture
def mock_cloudkit_service():
    return Mock(spec=CloudKitService)

@pytest.fixture
def connection_manager(mock_cloudkit_service):
    return ConnectionManager(cloudkit_service=mock_cloudkit_service)

class TestConnectionManager:
    def test_initialize_connection(self, connection_manager, mock_cloudkit_service):
        # Given
        device_id = "test-device-id"
        device_name = "Test Device"
        
        # When
        connection_manager.initialize_connection(device_id, device_name)
        
        # Then
        mock_cloudkit_service.initialize_device_record.assert_called_once_with(
            device_id, device_name
        )
        assert connection_manager.device_id == device_id
        assert connection_manager.device_name == device_name
        assert connection_manager.is_connected is True

    def test_handle_client_connection(self, connection_manager, mock_cloudkit_service):
        # Given
        device_id = "test-device-id"
        device_name = "Test Device"
        connection_manager.initialize_connection(device_id, device_name)
        
        # When
        connection_manager.handle_client_connection()
        
        # Then
        mock_cloudkit_service.update_device_status.assert_called_once_with(
            device_id, True
        )
        assert connection_manager.is_connected is True
        assert connection_manager.last_heartbeat is not None

    def test_handle_client_disconnection(self, connection_manager, mock_cloudkit_service):
        # Given
        device_id = "test-device-id"
        device_name = "Test Device"
        connection_manager.initialize_connection(device_id, device_name)
        connection_manager.handle_client_connection()
        
        # When
        connection_manager.handle_client_disconnection()
        
        # Then
        mock_cloudkit_service.update_device_status.assert_called_with(
            device_id, False
        )
        assert connection_manager.is_connected is False
        assert connection_manager.last_heartbeat is None

    def test_update_heartbeat(self, connection_manager, mock_cloudkit_service):
        # Given
        device_id = "test-device-id"
        device_name = "Test Device"
        connection_manager.initialize_connection(device_id, device_name)
        
        # When
        connection_manager.update_heartbeat()
        
        # Then
        mock_cloudkit_service.update_device_status.assert_called_once_with(
            device_id, True
        )
        assert connection_manager.last_heartbeat is not None

    def test_check_connection_timeout(self, connection_manager, mock_cloudkit_service):
        # Given
        device_id = "test-device-id"
        device_name = "Test Device"
        connection_manager.initialize_connection(device_id, device_name)
        connection_manager.handle_client_connection()
        
        # Simulate time passing
        connection_manager.last_heartbeat = datetime.now().timestamp() - 31
        
        # When
        is_timeout = connection_manager.check_connection_timeout()
        
        # Then
        assert is_timeout is True
        mock_cloudkit_service.update_device_status.assert_called_with(
            device_id, False
        )
        assert connection_manager.is_connected is False

    def test_get_connection_status(self, connection_manager):
        # Given
        device_id = "test-device-id"
        device_name = "Test Device"
        connection_manager.initialize_connection(device_id, device_name)
        
        # When
        status = connection_manager.get_connection_status()
        
        # Then
        assert status["deviceId"] == device_id
        assert status["deviceName"] == device_name
        assert status["isConnected"] is True
        assert "lastHeartbeat" in status

    def test_error_handling(self, connection_manager, mock_cloudkit_service):
        # Given
        device_id = "test-device-id"
        device_name = "Test Device"
        mock_cloudkit_service.initialize_device_record.side_effect = Exception("Test error")
        
        # When/Then
        with pytest.raises(Exception) as exc_info:
            connection_manager.initialize_connection(device_id, device_name)
        assert str(exc_info.value) == "Test error" 