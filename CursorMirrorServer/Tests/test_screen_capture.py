import pytest
from unittest.mock import Mock, patch
import numpy as np
from cursor_mirror_server.screen_capture import ScreenCaptureManager
from cursor_mirror_server.frame_processor import FrameProcessor

@pytest.fixture
def mock_frame_processor():
    return Mock(spec=FrameProcessor)

@pytest.fixture
def screen_capture_manager(mock_frame_processor):
    return ScreenCaptureManager(frame_processor=mock_frame_processor)

class TestScreenCaptureManager:
    def test_initialize_capture(self, screen_capture_manager):
        # When
        screen_capture_manager.initialize_capture()
        
        # Then
        assert screen_capture_manager.is_capturing is False
        assert screen_capture_manager.frame_rate == 30
        assert screen_capture_manager.quality == 0.8

    def test_start_capture(self, screen_capture_manager, mock_frame_processor):
        # Given
        screen_capture_manager.initialize_capture()
        
        # When
        screen_capture_manager.start_capture()
        
        # Then
        assert screen_capture_manager.is_capturing is True
        mock_frame_processor.initialize.assert_called_once()

    def test_stop_capture(self, screen_capture_manager, mock_frame_processor):
        # Given
        screen_capture_manager.initialize_capture()
        screen_capture_manager.start_capture()
        
        # When
        screen_capture_manager.stop_capture()
        
        # Then
        assert screen_capture_manager.is_capturing is False
        mock_frame_processor.cleanup.assert_called_once()

    def test_capture_frame(self, screen_capture_manager, mock_frame_processor):
        # Given
        screen_capture_manager.initialize_capture()
        screen_capture_manager.start_capture()
        mock_frame = np.zeros((100, 100, 3), dtype=np.uint8)
        mock_frame_processor.process_frame.return_value = mock_frame
        
        # When
        frame = screen_capture_manager.capture_frame()
        
        # Then
        assert frame is not None
        assert frame.shape == (100, 100, 3)
        mock_frame_processor.process_frame.assert_called_once()

    def test_update_settings(self, screen_capture_manager):
        # Given
        screen_capture_manager.initialize_capture()
        new_frame_rate = 60
        new_quality = 0.9
        
        # When
        screen_capture_manager.update_settings(
            frame_rate=new_frame_rate,
            quality=new_quality
        )
        
        # Then
        assert screen_capture_manager.frame_rate == new_frame_rate
        assert screen_capture_manager.quality == new_quality

    def test_get_capture_stats(self, screen_capture_manager, mock_frame_processor):
        # Given
        screen_capture_manager.initialize_capture()
        mock_frame_processor.get_stats.return_value = {
            "fps": 30.0,
            "frame_count": 100,
            "processing_time": 0.016
        }
        
        # When
        stats = screen_capture_manager.get_capture_stats()
        
        # Then
        assert "fps" in stats
        assert "frame_count" in stats
        assert "processing_time" in stats
        mock_frame_processor.get_stats.assert_called_once()

    def test_error_handling(self, screen_capture_manager, mock_frame_processor):
        # Given
        screen_capture_manager.initialize_capture()
        mock_frame_processor.process_frame.side_effect = Exception("Test error")
        
        # When/Then
        with pytest.raises(Exception) as exc_info:
            screen_capture_manager.capture_frame()
        assert str(exc_info.value) == "Test error"

class TestFrameProcessor:
    def test_initialize(self):
        # Given
        processor = FrameProcessor()
        
        # When
        processor.initialize()
        
        # Then
        assert processor.is_initialized is True

    def test_process_frame(self):
        # Given
        processor = FrameProcessor()
        processor.initialize()
        frame = np.zeros((100, 100, 3), dtype=np.uint8)
        
        # When
        processed_frame = processor.process_frame(frame)
        
        # Then
        assert processed_frame is not None
        assert processed_frame.shape == (100, 100, 3)

    def test_cleanup(self):
        # Given
        processor = FrameProcessor()
        processor.initialize()
        
        # When
        processor.cleanup()
        
        # Then
        assert processor.is_initialized is False

    def test_get_stats(self):
        # Given
        processor = FrameProcessor()
        processor.initialize()
        
        # When
        stats = processor.get_stats()
        
        # Then
        assert "fps" in stats
        assert "frame_count" in stats
        assert "processing_time" in stats

    def test_error_handling(self):
        # Given
        processor = FrameProcessor()
        
        # When/Then
        with pytest.raises(Exception) as exc_info:
            processor.process_frame(None)
        assert "Not initialized" in str(exc_info.value) 