import { useState, useEffect } from 'react'
import axios from 'axios'
import './App.css'

function App() {
  const [counter, setCounter] = useState(0)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [lastUpdated, setLastUpdated] = useState(null)

  const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000'

  // Fetch counter on component mount
  useEffect(() => {
    fetchCounter()
    // Poll every 2 seconds
    const interval = setInterval(fetchCounter, 2000)
    return () => clearInterval(interval)
  }, [])

  const fetchCounter = async () => {
    try {
      setLoading(true)
      setError(null)
      const response = await axios.get(`${API_URL}/`)
      setCounter(response.data.counter)
      setLastUpdated(new Date(response.data.timestamp).toLocaleTimeString())
    } catch (err) {
      setError(`Failed to fetch counter: ${err.message}`)
      console.error('Error fetching counter:', err)
    } finally {
      setLoading(false)
    }
  }

  const incrementCounter = async () => {
    try {
      setLoading(true)
      setError(null)
      const response = await axios.post(`${API_URL}/`)
      setCounter(response.data.counter)
      setLastUpdated(new Date(response.data.timestamp).toLocaleTimeString())
    } catch (err) {
      setError(`Failed to increment counter: ${err.message}`)
      console.error('Error incrementing counter:', err)
    } finally {
      setLoading(false)
    }
  }

  const resetCounter = async () => {
    try {
      setLoading(true)
      setError(null)
      const response = await axios.post(`${API_URL}/reset`)
      setCounter(response.data.counter)
      setLastUpdated(new Date(response.data.timestamp).toLocaleTimeString())
    } catch (err) {
      setError(`Failed to reset counter: ${err.message}`)
      console.error('Error resetting counter:', err)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="container">
      <header className="header">
        <h1>Counter Service</h1>
        <p className="subtitle">A production-ready counter with PostgreSQL persistence</p>
      </header>

      <main className="main">
        <div className="counter-box">
          <div className="counter-display">
            {loading && <div className="spinner"></div>}
            <div className="counter-value">{counter}</div>
          </div>

          <div className="button-group">
            <button 
              onClick={incrementCounter} 
              disabled={loading}
              className="btn btn-primary"
            >
              {loading ? 'Loading...' : 'Increment'}
            </button>
            <button 
              onClick={resetCounter} 
              disabled={loading}
              className="btn btn-danger"
            >
              {loading ? 'Loading...' : 'Reset'}
            </button>
            <button 
              onClick={fetchCounter} 
              disabled={loading}
              className="btn btn-secondary"
            >
              {loading ? 'Loading...' : 'Refresh'}
            </button>
          </div>

          {lastUpdated && (
            <div className="last-updated">
              Last updated: {lastUpdated}
            </div>
          )}
        </div>

        {error && (
          <div className="error-box">
            <p>⚠️ {error}</p>
          </div>
        )}

        <div className="info-box">
          <h2>Features</h2>
          <ul>
            <li>✅ PostgreSQL persistence</li>
            <li>✅ Structured JSON logging</li>
            <li>✅ Prometheus metrics</li>
            <li>✅ OpenTelemetry tracing</li>
            <li>✅ Health checks</li>
            <li>✅ Graceful shutdown</li>
          </ul>
        </div>

        <div className="info-box">
          <h2>API Endpoints</h2>
          <ul>
            <li><code>GET /</code> - Get counter value</li>
            <li><code>POST /</code> - Increment counter</li>
            <li><code>POST /reset</code> - Reset counter</li>
            <li><code>GET /health</code> - Health check</li>
            <li><code>GET /readiness</code> - Readiness probe</li>
            <li><code>GET /metrics</code> - Prometheus metrics</li>
          </ul>
        </div>
      </main>

      <footer className="footer">
        <p>Built with React + FastAPI + PostgreSQL</p>
      </footer>
    </div>
  )
}

export default App