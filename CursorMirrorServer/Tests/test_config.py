import pytest
from unittest.mock import Mock, patch
import os
from cursor_mirror_server.config import Config, load_config, save_config

@pytest.fixture
def test_config():
    return {
        "server": {
            "host": "127.0.0.1",
            "port": 8000,
            "debug": False
        },
        "streaming": {
            "frame_rate": 30,
            "quality": 0.8,
            "segment_duration": 2,
            "max_segments": 10
        },
        "optimization": {
            "target_fps": 30,
            "target_quality": 0.8,
            "min_quality": 0.4,
            "max_quality": 1.0,
            "update_interval": 5
        },
        "cloudkit": {
            "container_id": "test-container",
            "environment": "development"
        }
    }

@pytest.fixture
def config_file(tmp_path, test_config):
    config_path = tmp_path / "config.json"
    with open(config_path, "w") as f:
        import json
        json.dump(test_config, f)
    return config_path

class TestConfig:
    def test_config_initialization(self, test_config):
        # When
        config = Config(**test_config)
        
        # Then
        assert config.server.host == "127.0.0.1"
        assert config.server.port == 8000
        assert config.server.debug is False
        assert config.streaming.frame_rate == 30
        assert config.streaming.quality == 0.8
        assert config.streaming.segment_duration == 2
        assert config.streaming.max_segments == 10
        assert config.optimization.target_fps == 30
        assert config.optimization.target_quality == 0.8
        assert config.optimization.min_quality == 0.4
        assert config.optimization.max_quality == 1.0
        assert config.optimization.update_interval == 5
        assert config.cloudkit.container_id == "test-container"
        assert config.cloudkit.environment == "development"

    def test_load_config(self, config_file):
        # When
        config = load_config(config_file)
        
        # Then
        assert config.server.host == "127.0.0.1"
        assert config.server.port == 8000
        assert config.streaming.frame_rate == 30
        assert config.optimization.target_fps == 30
        assert config.cloudkit.container_id == "test-container"

    def test_save_config(self, tmp_path, test_config):
        # Given
        config = Config(**test_config)
        config_path = tmp_path / "config.json"
        
        # When
        save_config(config, config_path)
        
        # Then
        assert os.path.exists(config_path)
        loaded_config = load_config(config_path)
        assert loaded_config.server.host == config.server.host
        assert loaded_config.server.port == config.server.port
        assert loaded_config.streaming.frame_rate == config.streaming.frame_rate
        assert loaded_config.optimization.target_fps == config.optimization.target_fps
        assert loaded_config.cloudkit.container_id == config.cloudkit.container_id

    def test_config_validation(self):
        # Given
        invalid_config = {
            "server": {
                "host": "127.0.0.1",
                "port": -1,  # Invalid port
                "debug": False
            },
            "streaming": {
                "frame_rate": -1,  # Invalid frame rate
                "quality": 1.5,  # Invalid quality
                "segment_duration": 0,  # Invalid duration
                "max_segments": 0  # Invalid max segments
            },
            "optimization": {
                "target_fps": -1,  # Invalid target FPS
                "target_quality": 1.5,  # Invalid quality
                "min_quality": 1.5,  # Invalid quality
                "max_quality": 0.5,  # Invalid max quality
                "update_interval": 0  # Invalid interval
            },
            "cloudkit": {
                "container_id": "",  # Invalid container ID
                "environment": "invalid"  # Invalid environment
            }
        }
        
        # When/Then
        with pytest.raises(ValueError):
            Config(**invalid_config)

    def test_config_update(self, test_config):
        # Given
        config = Config(**test_config)
        
        # When
        config.server.port = 8080
        config.streaming.frame_rate = 60
        config.optimization.target_fps = 60
        config.cloudkit.environment = "production"
        
        # Then
        assert config.server.port == 8080
        assert config.streaming.frame_rate == 60
        assert config.optimization.target_fps == 60
        assert config.cloudkit.environment == "production"

    def test_config_defaults(self):
        # Given
        minimal_config = {
            "server": {
                "host": "127.0.0.1"
            }
        }
        
        # When
        config = Config(**minimal_config)
        
        # Then
        assert config.server.port == 8000  # Default port
        assert config.server.debug is False  # Default debug
        assert config.streaming.frame_rate == 30  # Default frame rate
        assert config.streaming.quality == 0.8  # Default quality
        assert config.streaming.segment_duration == 2  # Default duration
        assert config.streaming.max_segments == 10  # Default max segments
        assert config.optimization.target_fps == 30  # Default target FPS
        assert config.optimization.target_quality == 0.8  # Default target quality
        assert config.optimization.min_quality == 0.4  # Default min quality
        assert config.optimization.max_quality == 1.0  # Default max quality
        assert config.optimization.update_interval == 5  # Default interval
        assert config.cloudkit.container_id == "iCloud.com.cursor.mirror"  # Default container ID
        assert config.cloudkit.environment == "development"  # Default environment

    def test_config_environment_variables(self):
        # Given
        with patch.dict(os.environ, {
            "CURSOR_MIRROR_HOST": "0.0.0.0",
            "CURSOR_MIRROR_PORT": "8080",
            "CURSOR_MIRROR_DEBUG": "true",
            "CURSOR_MIRROR_FRAME_RATE": "60",
            "CURSOR_MIRROR_QUALITY": "0.9",
            "CURSOR_MIRROR_CLOUDKIT_ENV": "production"
        }):
            # When
            config = Config()
            
            # Then
            assert config.server.host == "0.0.0.0"
            assert config.server.port == 8080
            assert config.server.debug is True
            assert config.streaming.frame_rate == 60
            assert config.streaming.quality == 0.9
            assert config.cloudkit.environment == "production"

    def test_config_serialization(self, test_config):
        # Given
        config = Config(**test_config)
        
        # When
        config_dict = config.to_dict()
        
        # Then
        assert config_dict["server"]["host"] == config.server.host
        assert config_dict["server"]["port"] == config.server.port
        assert config_dict["streaming"]["frame_rate"] == config.streaming.frame_rate
        assert config_dict["optimization"]["target_fps"] == config.optimization.target_fps
        assert config_dict["cloudkit"]["container_id"] == config.cloudkit.container_id 