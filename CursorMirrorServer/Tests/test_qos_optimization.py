import pytest
from unittest.mock import Mock, patch
from cursor_mirror_server.qos_optimization import QoSOptimizer
from cursor_mirror_server.screen_capture import ScreenCaptureManager
from cursor_mirror_server.hls_streaming import HLSStreamManager

@pytest.fixture
def mock_screen_capture():
    return Mock(spec=ScreenCaptureManager)

@pytest.fixture
def mock_hls_stream():
    return Mock(spec=HLSStreamManager)

@pytest.fixture
def qos_optimizer(mock_screen_capture, mock_hls_stream):
    return QoSOptimizer(
        screen_capture=mock_screen_capture,
        hls_stream=mock_hls_stream
    )

class TestQoSOptimizer:
    def test_initialize_optimizer(self, qos_optimizer):
        # When
        qos_optimizer.initialize()
        
        # Then
        assert qos_optimizer.is_optimizing is False
        assert qos_optimizer.target_fps == 30
        assert qos_optimizer.target_quality == 0.8
        assert qos_optimizer.min_quality == 0.4
        assert qos_optimizer.max_quality == 1.0

    def test_start_optimization(self, qos_optimizer):
        # Given
        qos_optimizer.initialize()
        
        # When
        qos_optimizer.start_optimization()
        
        # Then
        assert qos_optimizer.is_optimizing is True

    def test_stop_optimization(self, qos_optimizer):
        # Given
        qos_optimizer.initialize()
        qos_optimizer.start_optimization()
        
        # When
        qos_optimizer.stop_optimization()
        
        # Then
        assert qos_optimizer.is_optimizing is False

    def test_update_metrics(self, qos_optimizer):
        # Given
        qos_optimizer.initialize()
        metrics = {
            "fps": 25.0,
            "processing_time": 0.05,
            "bandwidth": 5000000,
            "latency": 100
        }
        
        # When
        qos_optimizer.update_metrics(metrics)
        
        # Then
        assert qos_optimizer.current_fps == 25.0
        assert qos_optimizer.current_processing_time == 0.05
        assert qos_optimizer.current_bandwidth == 5000000
        assert qos_optimizer.current_latency == 100

    def test_optimize_quality(self, qos_optimizer, mock_screen_capture, mock_hls_stream):
        # Given
        qos_optimizer.initialize()
        qos_optimizer.start_optimization()
        qos_optimizer.update_metrics({
            "fps": 20.0,
            "processing_time": 0.05,
            "bandwidth": 5000000,
            "latency": 100
        })
        
        # When
        qos_optimizer.optimize_quality()
        
        # Then
        mock_screen_capture.update_settings.assert_called_once()
        mock_hls_stream.update_settings.assert_called_once()

    def test_optimize_frame_rate(self, qos_optimizer, mock_screen_capture):
        # Given
        qos_optimizer.initialize()
        qos_optimizer.start_optimization()
        qos_optimizer.update_metrics({
            "fps": 20.0,
            "processing_time": 0.05,
            "bandwidth": 5000000,
            "latency": 100
        })
        
        # When
        qos_optimizer.optimize_frame_rate()
        
        # Then
        mock_screen_capture.update_settings.assert_called_once()

    def test_get_optimization_stats(self, qos_optimizer):
        # Given
        qos_optimizer.initialize()
        qos_optimizer.start_optimization()
        qos_optimizer.update_metrics({
            "fps": 25.0,
            "processing_time": 0.05,
            "bandwidth": 5000000,
            "latency": 100
        })
        
        # When
        stats = qos_optimizer.get_optimization_stats()
        
        # Then
        assert "current_fps" in stats
        assert "current_quality" in stats
        assert "current_processing_time" in stats
        assert "current_bandwidth" in stats
        assert "current_latency" in stats
        assert "optimization_count" in stats

    def test_error_handling(self, qos_optimizer, mock_screen_capture):
        # Given
        qos_optimizer.initialize()
        mock_screen_capture.update_settings.side_effect = Exception("Test error")
        
        # When/Then
        with pytest.raises(Exception) as exc_info:
            qos_optimizer.optimize_quality()
        assert str(exc_info.value) == "Test error"

    def test_quality_bounds(self, qos_optimizer, mock_screen_capture):
        # Given
        qos_optimizer.initialize()
        qos_optimizer.start_optimization()
        
        # When
        qos_optimizer.update_metrics({
            "fps": 10.0,
            "processing_time": 0.1,
            "bandwidth": 1000000,
            "latency": 200
        })
        qos_optimizer.optimize_quality()
        
        # Then
        call_args = mock_screen_capture.update_settings.call_args[1]
        assert call_args["quality"] >= qos_optimizer.min_quality
        assert call_args["quality"] <= qos_optimizer.max_quality

    def test_frame_rate_bounds(self, qos_optimizer, mock_screen_capture):
        # Given
        qos_optimizer.initialize()
        qos_optimizer.start_optimization()
        
        # When
        qos_optimizer.update_metrics({
            "fps": 10.0,
            "processing_time": 0.1,
            "bandwidth": 1000000,
            "latency": 200
        })
        qos_optimizer.optimize_frame_rate()
        
        # Then
        call_args = mock_screen_capture.update_settings.call_args[1]
        assert call_args["frame_rate"] >= 15  # Minimum frame rate
        assert call_args["frame_rate"] <= 30  # Maximum frame rate 