import pytest
from unittest.mock import Mock, patch
from fastapi import HTTPException
from cursor_mirror_server.error_handling import (
    handle_connection_error,
    handle_stream_error,
    handle_cloudkit_error,
    handle_validation_error,
    handle_generic_error
)

class TestErrorHandling:
    def test_handle_connection_error(self):
        # Given
        error = Exception("Connection failed")
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_connection_error(error)
        assert exc_info.value.status_code == 503
        assert "Connection failed" in str(exc_info.value.detail)

    def test_handle_stream_error(self):
        # Given
        error = Exception("Stream error")
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_stream_error(error)
        assert exc_info.value.status_code == 500
        assert "Stream error" in str(exc_info.value.detail)

    def test_handle_cloudkit_error(self):
        # Given
        error = Exception("CloudKit error")
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_cloudkit_error(error)
        assert exc_info.value.status_code == 503
        assert "CloudKit error" in str(exc_info.value.detail)

    def test_handle_validation_error(self):
        # Given
        error = ValueError("Invalid input")
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_validation_error(error)
        assert exc_info.value.status_code == 422
        assert "Invalid input" in str(exc_info.value.detail)

    def test_handle_generic_error(self):
        # Given
        error = Exception("Generic error")
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_generic_error(error)
        assert exc_info.value.status_code == 500
        assert "Generic error" in str(exc_info.value.detail)

    def test_error_handling_with_context(self):
        # Given
        error = Exception("Test error")
        context = "Connection to device"
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_connection_error(error, context)
        assert exc_info.value.status_code == 503
        assert "Connection to device" in str(exc_info.value.detail)
        assert "Test error" in str(exc_info.value.detail)

    def test_error_handling_with_nested_exceptions(self):
        # Given
        inner_error = ValueError("Inner error")
        outer_error = Exception("Outer error")
        outer_error.__cause__ = inner_error
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_generic_error(outer_error)
        assert exc_info.value.status_code == 500
        assert "Outer error" in str(exc_info.value.detail)
        assert "Inner error" in str(exc_info.value.detail)

    def test_error_handling_with_custom_status_code(self):
        # Given
        error = Exception("Custom error")
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_generic_error(error, status_code=400)
        assert exc_info.value.status_code == 400
        assert "Custom error" in str(exc_info.value.detail)

    def test_error_handling_with_empty_message(self):
        # Given
        error = Exception()
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_generic_error(error)
        assert exc_info.value.status_code == 500
        assert "An unexpected error occurred" in str(exc_info.value.detail)

    def test_error_handling_with_special_characters(self):
        # Given
        error = Exception("Error with special chars: !@#$%^&*()")
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_generic_error(error)
        assert exc_info.value.status_code == 500
        assert "Error with special chars: !@#$%^&*()" in str(exc_info.value.detail)

    def test_error_handling_with_unicode(self):
        # Given
        error = Exception("Error with unicode: 你好世界")
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_generic_error(error)
        assert exc_info.value.status_code == 500
        assert "Error with unicode: 你好世界" in str(exc_info.value.detail)

    def test_error_handling_with_long_message(self):
        # Given
        long_message = "x" * 1000
        error = Exception(long_message)
        
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_generic_error(error)
        assert exc_info.value.status_code == 500
        assert len(str(exc_info.value.detail)) <= 500  # Should be truncated

    def test_error_handling_with_none(self):
        # When/Then
        with pytest.raises(HTTPException) as exc_info:
            handle_generic_error(None)
        assert exc_info.value.status_code == 500
        assert "An unexpected error occurred" in str(exc_info.value.detail) 