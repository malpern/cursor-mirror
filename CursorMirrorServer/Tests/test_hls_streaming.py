import pytest
from unittest.mock import Mock, patch
import os
from cursor_mirror_server.hls_streaming import HLSStreamManager
from cursor_mirror_server.screen_capture import ScreenCaptureManager

@pytest.fixture
def mock_screen_capture():
    return Mock(spec=ScreenCaptureManager)

@pytest.fixture
def hls_stream_manager(mock_screen_capture):
    return HLSStreamManager(screen_capture=mock_screen_capture)

class TestHLSStreamManager:
    def test_initialize_stream(self, hls_stream_manager):
        # When
        hls_stream_manager.initialize_stream()
        
        # Then
        assert hls_stream_manager.is_streaming is False
        assert hls_stream_manager.segment_duration == 2
        assert hls_stream_manager.output_dir is not None
        assert os.path.exists(hls_stream_manager.output_dir)

    def test_start_streaming(self, hls_stream_manager, mock_screen_capture):
        # Given
        hls_stream_manager.initialize_stream()
        mock_screen_capture.is_capturing = True
        
        # When
        hls_stream_manager.start_streaming()
        
        # Then
        assert hls_stream_manager.is_streaming is True
        mock_screen_capture.start_capture.assert_called_once()

    def test_stop_streaming(self, hls_stream_manager, mock_screen_capture):
        # Given
        hls_stream_manager.initialize_stream()
        hls_stream_manager.start_streaming()
        
        # When
        hls_stream_manager.stop_streaming()
        
        # Then
        assert hls_stream_manager.is_streaming is False
        mock_screen_capture.stop_capture.assert_called_once()

    def test_create_segment(self, hls_stream_manager, mock_screen_capture):
        # Given
        hls_stream_manager.initialize_stream()
        mock_frame = Mock()
        mock_screen_capture.capture_frame.return_value = mock_frame
        
        # When
        segment_path = hls_stream_manager.create_segment()
        
        # Then
        assert segment_path is not None
        assert os.path.exists(segment_path)
        mock_screen_capture.capture_frame.assert_called_once()

    def test_update_playlist(self, hls_stream_manager):
        # Given
        hls_stream_manager.initialize_stream()
        segment_path = "test_segment.ts"
        
        # When
        hls_stream_manager.update_playlist(segment_path)
        
        # Then
        playlist_path = os.path.join(hls_stream_manager.output_dir, "playlist.m3u8")
        assert os.path.exists(playlist_path)
        with open(playlist_path, "r") as f:
            content = f.read()
            assert segment_path in content

    def test_get_stream_url(self, hls_stream_manager):
        # Given
        hls_stream_manager.initialize_stream()
        
        # When
        url = hls_stream_manager.get_stream_url()
        
        # Then
        assert url is not None
        assert url.startswith("http://")
        assert "playlist.m3u8" in url

    def test_cleanup_old_segments(self, hls_stream_manager):
        # Given
        hls_stream_manager.initialize_stream()
        old_segment = os.path.join(hls_stream_manager.output_dir, "old_segment.ts")
        with open(old_segment, "w") as f:
            f.write("test")
        
        # When
        hls_stream_manager.cleanup_old_segments()
        
        # Then
        assert not os.path.exists(old_segment)

    def test_error_handling(self, hls_stream_manager, mock_screen_capture):
        # Given
        hls_stream_manager.initialize_stream()
        mock_screen_capture.capture_frame.side_effect = Exception("Test error")
        
        # When/Then
        with pytest.raises(Exception) as exc_info:
            hls_stream_manager.create_segment()
        assert str(exc_info.value) == "Test error"

    def test_stream_quality_settings(self, hls_stream_manager):
        # Given
        hls_stream_manager.initialize_stream()
        new_quality = 0.9
        new_segment_duration = 4
        
        # When
        hls_stream_manager.update_settings(
            quality=new_quality,
            segment_duration=new_segment_duration
        )
        
        # Then
        assert hls_stream_manager.quality == new_quality
        assert hls_stream_manager.segment_duration == new_segment_duration

    def test_stream_stats(self, hls_stream_manager):
        # Given
        hls_stream_manager.initialize_stream()
        mock_screen_capture.get_capture_stats.return_value = {
            "fps": 30.0,
            "frame_count": 100,
            "processing_time": 0.016
        }
        
        # When
        stats = hls_stream_manager.get_stream_stats()
        
        # Then
        assert "fps" in stats
        assert "frame_count" in stats
        assert "processing_time" in stats
        assert "segment_count" in stats
        mock_screen_capture.get_capture_stats.assert_called_once() 