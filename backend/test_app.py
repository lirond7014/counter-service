"""Unit tests for counter service"""

from unittest.mock import MagicMock, patch

import psycopg2
import pytest

# Mock psycopg2 pool BEFORE importing app
with patch('psycopg2.pool.SimpleConnectionPool'):
    from app import app, get_value, increment, reset

from fastapi.testclient import TestClient

client = TestClient(app)


class TestDatabaseOperations:
    """Test database helper functions"""
    
    @patch('app.pool')
    def test_get_value(self, mock_pool):
        """Test getting counter value"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_pool.getconn.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchone.return_value = (42,)
        
        result = get_value()
        
        assert result == 42
        mock_pool.getconn.assert_called_once()
        mock_pool.putconn.assert_called_once_with(mock_conn)
    
    @patch('app.pool')
    def test_get_value_returns_zero_if_no_row(self, mock_pool):
        """Test getting counter when table is empty"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_pool.getconn.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchone.return_value = None
        
        result = get_value()
        
        assert result == 0
    
    @patch('app.pool')
    def test_increment(self, mock_pool):
        """Test incrementing counter"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_pool.getconn.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchone.return_value = (43,)
        
        result = increment()
        
        assert result == 43
        mock_pool.getconn.assert_called_once()
        mock_conn.commit.assert_called_once()
        mock_pool.putconn.assert_called_once_with(mock_conn)
    
    @patch('app.pool')
    def test_increment_with_error_rolls_back(self, mock_pool):
        """Test that errors rollback the transaction"""
        mock_conn = MagicMock()
        mock_pool.getconn.return_value = mock_conn
        mock_conn.cursor.side_effect = psycopg2.Error("DB Error")
        
        with pytest.raises(psycopg2.Error):
            increment()
        
        mock_conn.rollback.assert_called_once()
    
    @patch('app.pool')
    def test_reset(self, mock_pool):
        """Test resetting counter"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_pool.getconn.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        
        result = reset()
        
        assert result == 0
        mock_conn.commit.assert_called_once()
        mock_pool.putconn.assert_called_once_with(mock_conn)


class TestAPIEndpoints:
    """Test API endpoints"""
    
    @patch('app.get_value')
    def test_get_counter_endpoint(self, mock_get_value):
        """Test GET / endpoint"""
        mock_get_value.return_value = 42
        
        response = client.get("/")
        
        assert response.status_code == 200
        data = response.json()
        assert data["counter"] == 42
        assert "timestamp" in data
    
    @patch('app.increment')
    def test_increment_endpoint(self, mock_increment):
        """Test POST / endpoint"""
        mock_increment.return_value = 43
        
        response = client.post("/")
        
        assert response.status_code == 200
        data = response.json()
        assert data["counter"] == 43
        assert "timestamp" in data
    
    @patch('app.reset')
    def test_reset_endpoint(self, mock_reset):
        """Test POST /reset endpoint"""
        mock_reset.return_value = 0
        
        response = client.post("/reset")
        
        assert response.status_code == 200
        data = response.json()
        assert data["counter"] == 0
        assert "timestamp" in data
    
    @patch('app.get_value')
    def test_health_endpoint_healthy(self, mock_get_value):
        """Test GET /health endpoint when healthy"""
        mock_get_value.return_value = 42
        
        response = client.get("/health")
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "counter-service"
        assert "version" in data
    
    @patch('app.get_value')
    def test_health_endpoint_unhealthy(self, mock_get_value):
        """Test health check when database fails"""
        mock_get_value.side_effect = Exception("DB connection failed")
        
        response = client.get("/health")
        
        assert response.status_code == 503
    
    @patch('app.get_value')
    def test_readiness_endpoint_ready(self, mock_get_value):
        """Test GET /readiness endpoint when ready"""
        mock_get_value.return_value = 42
        
        response = client.get("/readiness")
        
        assert response.status_code == 200
        data = response.json()
        assert data["ready"] is True
    
    @patch('app.get_value')
    def test_readiness_endpoint_not_ready(self, mock_get_value):
        """Test readiness check when database fails"""
        mock_get_value.side_effect = Exception("DB connection failed")
        
        response = client.get("/readiness")
        
        assert response.status_code == 503
    
    def test_metrics_endpoint(self):
        """Test GET /metrics endpoint"""
        response = client.get("/metrics")
        
        assert response.status_code == 200
        # Check that metrics are returned
        assert "counter_service_requests_total" in response.text
        assert "counter_service_increments_total" in response.text
        # Content type should be text/plain (prometheus format, not JSON)
        assert response.headers["content-type"].startswith("text/plain")
    
    @patch('app.get_value')
    def test_get_counter_error_handling(self, mock_get_value):
        """Test error handling when database fails"""
        mock_get_value.side_effect = Exception("Connection failed")
        
        response = client.get("/")
        
        assert response.status_code == 500
        data = response.json()
        assert "detail" in data
    
    @patch('app.increment')
    def test_increment_error_handling(self, mock_increment):
        """Test error handling on increment failure"""
        mock_increment.side_effect = Exception("Connection failed")
        
        response = client.post("/")
        
        assert response.status_code == 500
        data = response.json()
        assert "detail" in data
    
    @patch('app.reset')
    def test_reset_error_handling(self, mock_reset):
        """Test error handling on reset failure"""
        mock_reset.side_effect = Exception("Connection failed")
        
        response = client.post("/reset")
        
        assert response.status_code == 500
        data = response.json()
        assert "detail" in data


if __name__ == "__main__":
    pytest.main([__file__, "-v"])