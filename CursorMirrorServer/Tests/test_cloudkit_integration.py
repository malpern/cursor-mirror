import pytest
from unittest.mock import Mock, patch
from datetime import datetime
from cursor_mirror_server.cloudkit_integration import CloudKitService

@pytest.fixture
def mock_cloudkit():
    with patch('cursor_mirror_server.cloudkit_integration.CKContainer') as mock_container:
        mock_db = Mock()
        mock_container.return_value.publicCloudDatabase = mock_db
        yield mock_container, mock_db

@pytest.fixture
def cloudkit_service(mock_cloudkit):
    container, _ = mock_cloudkit
    service = CloudKitService(container=container())
    return service

class TestCloudKitService:
    def test_initialize_device_record(self, cloudkit_service, mock_cloudkit):
        # Given
        _, mock_db = mock_cloudkit
        device_id = "test-device-id"
        device_name = "Test Device"
        
        # When
        cloudkit_service.initialize_device_record(device_id, device_name)
        
        # Then
        mock_db.save.assert_called_once()
        record = mock_db.save.call_args[0][0]
        assert record.recordID.recordName == f"device_{device_id}"
        assert record["name"] == device_name
        assert record["deviceId"] == device_id
        assert "lastSeen" in record
        assert record["isOnline"] is True

    def test_update_device_status(self, cloudkit_service, mock_cloudkit):
        # Given
        _, mock_db = mock_cloudkit
        device_id = "test-device-id"
        is_online = True
        
        # When
        cloudkit_service.update_device_status(device_id, is_online)
        
        # Then
        mock_db.save.assert_called_once()
        record = mock_db.save.call_args[0][0]
        assert record.recordID.recordName == f"device_{device_id}"
        assert record["isOnline"] == is_online
        assert "lastSeen" in record

    def test_get_online_devices(self, cloudkit_service, mock_cloudkit):
        # Given
        _, mock_db = mock_cloudkit
        mock_record1 = Mock()
        mock_record1.recordID.recordName = "device_1"
        mock_record1["name"] = "Device 1"
        mock_record1["deviceId"] = "1"
        mock_record1["lastSeen"] = datetime.now()
        mock_record1["isOnline"] = True
        
        mock_record2 = Mock()
        mock_record2.recordID.recordName = "device_2"
        mock_record2["name"] = "Device 2"
        mock_record2["deviceId"] = "2"
        mock_record2["lastSeen"] = datetime.now()
        mock_record2["isOnline"] = False
        
        mock_db.performQuery.return_value = [mock_record1, mock_record2]
        
        # When
        devices = cloudkit_service.get_online_devices()
        
        # Then
        assert len(devices) == 1
        assert devices[0]["deviceId"] == "1"
        assert devices[0]["name"] == "Device 1"
        assert devices[0]["isOnline"] is True

    def test_handle_device_discovery(self, cloudkit_service, mock_cloudkit):
        # Given
        _, mock_db = mock_cloudkit
        device_id = "test-device-id"
        device_name = "Test Device"
        
        # When
        cloudkit_service.handle_device_discovery(device_id, device_name)
        
        # Then
        mock_db.save.assert_called_once()
        record = mock_db.save.call_args[0][0]
        assert record.recordID.recordName == f"device_{device_id}"
        assert record["name"] == device_name
        assert record["deviceId"] == device_id
        assert record["isOnline"] is True
        assert "lastSeen" in record

    def test_error_handling(self, cloudkit_service, mock_cloudkit):
        # Given
        _, mock_db = mock_cloudkit
        mock_db.save.side_effect = Exception("Test error")
        
        # When/Then
        with pytest.raises(Exception) as exc_info:
            cloudkit_service.initialize_device_record("test-id", "Test Device")
        assert str(exc_info.value) == "Test error" 