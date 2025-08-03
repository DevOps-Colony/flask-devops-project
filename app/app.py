import os
import sqlite3
from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
import re

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')

# Database configuration
DATABASE = os.environ.get('DATABASE_URL', 'app.db')
app.config['DATABASE'] = DATABASE

def init_db():
    """Initialize the database with required tables."""
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    
    # Create users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_login TIMESTAMP,
            is_active BOOLEAN DEFAULT 1,
            failed_login_attempts INTEGER DEFAULT 0,
            locked_until TIMESTAMP
        )
    ''')
    
    # Create sessions table for session management
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS user_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            session_token TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP NOT NULL,
            is_active BOOLEAN DEFAULT 1,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    conn.commit()
    conn.close()

def get_db_connection():
    """Get database connection."""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def validate_email(email):
    """Validate email format."""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None

def validate_password(password):
    """Validate password strength."""
    if len(password) < 8:
        return False, "Password must be at least 8 characters long"
    if not re.search(r'[A-Z]', password):
        return False, "Password must contain at least one uppercase letter"
    if not re.search(r'[a-z]', password):
        return False, "Password must contain at least one lowercase letter"
    if not re.search(r'\d', password):
        return False, "Password must contain at least one number"
    return True, "Password is valid"

def is_user_locked(username):
    """Check if user account is locked."""
    conn = get_db_connection()
    user = conn.execute(
        'SELECT locked_until FROM users WHERE username = ?', (username,)
    ).fetchone()
    conn.close()
    
    if user and user['locked_until']:
        locked_until = datetime.fromisoformat(user['locked_until'])
        if datetime.now() < locked_until:
            return True
    return False

def lock_user_account(username, duration_minutes=30):
    """Lock user account for specified duration."""
    locked_until = datetime.now() + timedelta(minutes=duration_minutes)
    conn = get_db_connection()
    conn.execute(
        'UPDATE users SET locked_until = ?, failed_login_attempts = 0 WHERE username = ?',
        (locked_until.isoformat(), username)
    )
    conn.commit()
    conn.close()

def increment_failed_attempts(username):
    """Increment failed login attempts."""
    conn = get_db_connection()
    user = conn.execute(
        'SELECT failed_login_attempts FROM users WHERE username = ?', (username,)
    ).fetchone()
    
    if user:
        new_attempts = (user['failed_login_attempts'] or 0) + 1
        conn.execute(
            'UPDATE users SET failed_login_attempts = ? WHERE username = ?',
            (new_attempts, username)
        )
        conn.commit()
        
        # Lock account after 5 failed attempts
        if new_attempts >= 5:
            lock_user_account(username)
            conn.close()
            return True  # Account locked
    
    conn.close()
    return False  # Account not locked

def reset_failed_attempts(username):
    """Reset failed login attempts on successful login."""
    conn = get_db_connection()
    conn.execute(
        'UPDATE users SET failed_login_attempts = 0, locked_until = NULL WHERE username = ?',
        (username,)
    )
    conn.commit()
    conn.close()

@app.route('/')
def index():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return render_template('index.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        email = request.form.get('email', '').strip()
        password = request.form.get('password', '')
        confirm_password = request.form.get('confirm_password', '')
        
        # Validation
        errors = []
        
        if not username:
            errors.append('Username is required')
        elif len(username) < 3:
            errors.append('Username must be at least 3 characters long')
        elif not re.match(r'^[a-zA-Z0-9_]+$', username):
            errors.append('Username can only contain letters, numbers, and underscores')
        
        if not email:
            errors.append('Email is required')
        elif not validate_email(email):
            errors.append('Please enter a valid email address')
        
        if not password:
            errors.append('Password is required')
        else:
            is_valid, message = validate_password(password)
            if not is_valid:
                errors.append(message)
        
        if not confirm_password:
            errors.append('Password confirmation is required')
        elif password != confirm_password:
            errors.append('Passwords do not match')
        
        if errors:
            for error in errors:
                flash(error, 'error')
            return render_template('register.html'), 400
        
        # Check if user already exists
        conn = get_db_connection()
        existing_user = conn.execute(
            'SELECT id FROM users WHERE username = ? OR email = ?', (username, email)
        ).fetchone()
        
        if existing_user:
            conn.close()
            flash('Username or email already exists', 'error')
            return render_template('register.html'), 400
        
        # Create new user
        password_hash = generate_password_hash(password)
        try:
            conn.execute(
                'INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)',
                (username, email, password_hash)
            )
            conn.commit()
            conn.close()
            
            flash('Registration successful! Please log in.', 'success')
            return redirect(url_for('login'))
        except sqlite3.Error as e:
            conn.close()
            flash('Registration failed. Please try again.', 'error')
            return render_template('register.html'), 500
    
    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        
        # Validation
        errors = []
        
        if not username:
            errors.append('Username is required')
        
        if not password:
            errors.append('Password is required')
        
        if errors:
            for error in errors:
                flash(error, 'error')
            return render_template('login.html'), 400
        
        # Check if account is locked
        if is_user_locked(username):
            flash('Account is temporarily locked due to too many failed attempts. Please try again later.', 'error')
            return render_template('login.html'), 400
        
        # Authenticate user
        conn = get_db_connection()
        user = conn.execute(
            'SELECT * FROM users WHERE username = ? AND is_active = 1', (username,)
        ).fetchone()
        
        if user and check_password_hash(user['password_hash'], password):
            # Successful login
            reset_failed_attempts(username)
            
            # Update last login
            conn.execute(
                'UPDATE users SET last_login = ? WHERE id = ?',
                (datetime.now().isoformat(), user['id'])
            )
            conn.commit()
            conn.close()
            
            # Set session
            session['user_id'] = user['id']
            session['username'] = user['username']
            session.permanent = True
            
            flash('Login successful!', 'success')
            return redirect(url_for('dashboard'))
        else:
            # Failed login
            conn.close()
            account_locked = increment_failed_attempts(username)
            
            if account_locked:
                flash('Too many failed attempts. Account has been locked for 30 minutes.', 'error')
            else:
                flash('Invalid username or password', 'error')
            
            return render_template('login.html'), 400
    
    return render_template('login.html')

@app.route('/dashboard')
def dashboard():
    if 'user_id' not in session:
        flash('Please log in to access the dashboard.', 'error')
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    user = conn.execute(
        'SELECT * FROM users WHERE id = ?', (session['user_id'],)
    ).fetchone()
    conn.close()
    
    if not user:
        session.clear()
        flash('User not found. Please log in again.', 'error')
        return redirect(url_for('login'))
    
    return render_template('dashboard.html', user=dict(user))

@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out successfully.', 'success')
    return redirect(url_for('index'))

@app.route('/health')
def health():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })

@app.route('/ready')
def ready():
    """Readiness check endpoint."""
    try:
        # Check database connectivity
        conn = get_db_connection()
        conn.execute('SELECT 1')
        conn.close()
        return jsonify({
            'status': 'ready',
            'timestamp': datetime.now().isoformat(),
            'database': 'connected'
        })
    except Exception as e:
        return jsonify({
            'status': 'not ready',
            'timestamp': datetime.now().isoformat(),
            'error': str(e)
        }), 503

# Initialize database when app starts
if __name__ == '__main__':
    init_db()
    app.run(debug=os.environ.get('FLASK_DEBUG', 'False').lower() == 'true', 
            host='0.0.0.0', 
            port=int(os.environ.get('PORT', 5000)))
else:
    # Initialize database when imported (for tests)
    init_db()
