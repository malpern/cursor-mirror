import pytest
from unittest.mock import Mock, patch
import os
import logging
from cursor_mirror_server.logging import setup_logging, get_logger

@pytest.fixture
def log_file(tmp_path):
    return tmp_path / "test.log"

@pytest.fixture
def test_config():
    return {
        "logging": {
            "level": "DEBUG",
            "file": "test.log",
            "max_size": 1024 * 1024,  # 1MB
            "backup_count": 3,
            "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        }
    }

class TestLogging:
    def test_setup_logging(self, log_file, test_config):
        # Given
        with patch('cursor_mirror_server.logging.Config') as mock_config:
            mock_config.return_value.logging.file = str(log_file)
            
            # When
            setup_logging(test_config)
            
            # Then
            assert os.path.exists(log_file)
            logger = logging.getLogger("cursor_mirror")
            assert logger.level == logging.DEBUG
            assert len(logger.handlers) > 0

    def test_get_logger(self):
        # When
        logger = get_logger("test_module")
        
        # Then
        assert isinstance(logger, logging.Logger)
        assert logger.name == "cursor_mirror.test_module"

    def test_log_rotation(self, log_file, test_config):
        # Given
        with patch('cursor_mirror_server.logging.Config') as mock_config:
            mock_config.return_value.logging.file = str(log_file)
            mock_config.return_value.logging.max_size = 100  # Small size for testing
            
            # When
            setup_logging(test_config)
            logger = get_logger("test_module")
            
            # Write enough logs to trigger rotation
            for i in range(100):
                logger.debug(f"Test log {i}")
            
            # Then
            assert os.path.exists(log_file)
            backup_files = [f for f in os.listdir(log_file.parent) if f.startswith("test.log.")]
            assert len(backup_files) > 0

    def test_log_levels(self, log_file, test_config):
        # Given
        with patch('cursor_mirror_server.logging.Config') as mock_config:
            mock_config.return_value.logging.file = str(log_file)
            
            # When
            setup_logging(test_config)
            logger = get_logger("test_module")
            
            # Then
            logger.debug("Debug message")
            logger.info("Info message")
            logger.warning("Warning message")
            logger.error("Error message")
            
            with open(log_file, "r") as f:
                log_content = f.read()
                assert "Debug message" in log_content
                assert "Info message" in log_content
                assert "Warning message" in log_content
                assert "Error message" in log_content

    def test_log_format(self, log_file, test_config):
        # Given
        with patch('cursor_mirror_server.logging.Config') as mock_config:
            mock_config.return_value.logging.file = str(log_file)
            
            # When
            setup_logging(test_config)
            logger = get_logger("test_module")
            logger.info("Test message")
            
            # Then
            with open(log_file, "r") as f:
                log_content = f.read()
                assert "cursor_mirror.test_module" in log_content
                assert "INFO" in log_content
                assert "Test message" in log_content

    def test_log_file_permissions(self, log_file, test_config):
        # Given
        with patch('cursor_mirror_server.logging.Config') as mock_config:
            mock_config.return_value.logging.file = str(log_file)
            
            # When
            setup_logging(test_config)
            
            # Then
            assert os.access(log_file, os.W_OK)
            assert os.access(log_file, os.R_OK)

    def test_log_directory_creation(self, tmp_path, test_config):
        # Given
        log_dir = tmp_path / "logs"
        log_file = log_dir / "test.log"
        with patch('cursor_mirror_server.logging.Config') as mock_config:
            mock_config.return_value.logging.file = str(log_file)
            
            # When
            setup_logging(test_config)
            
            # Then
            assert os.path.exists(log_dir)
            assert os.path.exists(log_file)

    def test_log_cleanup(self, log_file, test_config):
        # Given
        with patch('cursor_mirror_server.logging.Config') as mock_config:
            mock_config.return_value.logging.file = str(log_file)
            mock_config.return_value.logging.max_size = 100
            mock_config.return_value.logging.backup_count = 2
            
            # When
            setup_logging(test_config)
            logger = get_logger("test_module")
            
            # Write enough logs to trigger rotation and cleanup
            for i in range(300):
                logger.debug(f"Test log {i}")
            
            # Then
            backup_files = [f for f in os.listdir(log_file.parent) if f.startswith("test.log.")]
            assert len(backup_files) <= 2  # Should only keep 2 backup files

    def test_log_exception_handling(self, log_file, test_config):
        # Given
        with patch('cursor_mirror_server.logging.Config') as mock_config:
            mock_config.return_value.logging.file = str(log_file)
            
            # When
            setup_logging(test_config)
            logger = get_logger("test_module")
            
            try:
                raise ValueError("Test exception")
            except ValueError as e:
                logger.exception("Exception occurred")
            
            # Then
            with open(log_file, "r") as f:
                log_content = f.read()
                assert "Exception occurred" in log_content
                assert "ValueError" in log_content
                assert "Test exception" in log_content

    def test_log_thread_safety(self, log_file, test_config):
        # Given
        with patch('cursor_mirror_server.logging.Config') as mock_config:
            mock_config.return_value.logging.file = str(log_file)
            
            # When
            setup_logging(test_config)
            logger = get_logger("test_module")
            
            import threading
            threads = []
            for i in range(10):
                thread = threading.Thread(
                    target=lambda: logger.info(f"Thread {i} message")
                )
                threads.append(thread)
                thread.start()
            
            for thread in threads:
                thread.join()
            
            # Then
            with open(log_file, "r") as f:
                log_content = f.read()
                for i in range(10):
                    assert f"Thread {i} message" in log_content 