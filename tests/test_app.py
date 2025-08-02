import pytest
from app.app import app, get_db_connection, validate_email, validate_password

class TestHealthCheck:
    """Test health check endpoint."""
    
    def test_health_endpoint(self, client):
        """Test that health endpoint returns correct response."""
        response = client.get('/health')
        assert response.status_code == 200
        data = response.get_json()
        assert data['status'] == 'healthy'
        assert data['service'] == 'flask-auth-app'

class TestAuthentication:
    """Test authentication functionality."""
    
    def test_index_redirect_to_login(self, client):
        """Test that index redirects to login when not authenticated."""
        response = client.get('/')
        assert response.status_code == 302
        assert '/login' in response.location
    
    def test_login_page_loads(self, client):
        """Test that login page loads correctly."""
        response = client.get('/login')
        assert response.status_code == 200
        assert b'Login' in response.data
    
    def test_register_page_loads(self, client):
        """Test that register page loads correctly."""
        response = client.get('/register')
        assert response.status_code == 200
        assert b'Register' in response.data
    
    def test_successful_registration(self, client):
        """Test successful user registration."""
        response = client.post('/register', data={
            'username': 'newuser',
            'email': 'newuser@example.com',
            'password': 'SecurePass123',
            'confirm_password': 'SecurePass123'
        })
        assert response.status_code == 302
        assert '/login' in response.location
    
    def test_registration_with_existing_username(self, client):
        """Test registration with existing username fails."""
        # Register first user
        client.post('/register', data={
            'username': 'existinguser',
            'email': 'user1@example.com',
            'password': 'SecurePass123',
            'confirm_password': 'SecurePass123'
        })
        
        # Try to register with same username
        response = client.post('/register', data={
            'username': 'existinguser',
            'email': 'user2@example.com',
            'password': 'SecurePass123',
            'confirm_password': 'SecurePass123'
        })
        assert response.status_code == 200
        assert b'Username or email already exists' in response.data
    
    def test_registration_password_mismatch(self, client):
        """Test registration fails when passwords don't match."""
        response = client.post('/register', data={
            'username': 'testuser',
            'email': 'test@example.com',
            'password': 'SecurePass123',
            'confirm_password': 'DifferentPass123'
        })
        assert response.status_code == 200
        assert b'Passwords do not match' in response.data
    
    def test_successful_login(self, client):
        """Test successful login."""
        # Register user first
        client.post('/register', data={
            'username': 'loginuser',
            'email': 'login@example.com',
            'password': 'LoginPass123',
            'confirm_password': 'LoginPass123'
        })
        
        # Login
        response = client.post('/login', data={
            'username': 'loginuser',
            'password': 'LoginPass123'
        })
        assert response.status_code == 302
        assert '/dashboard' in response.location
    
    def test_login_with_wrong_password(self, client):
        """Test login fails with wrong password."""
        # Register user first
        client.post('/register', data={
            'username': 'loginuser',
            'email': 'login@example.com',
            'password': 'LoginPass123',
            'confirm_password': 'LoginPass123'
        })
        
        # Try login with wrong password
        response = client.post('/login', data={
            'username': 'loginuser',
            'password': 'WrongPassword'
        })
        assert response.status_code == 200
        assert b'Invalid username or password' in response.data
    
    def test_login_with_nonexistent_user(self, client):
        """Test login fails with nonexistent user."""
        response = client.post('/login', data={
            'username': 'nonexistent',
            'password': 'SomePassword123'
        })
        assert response.status_code == 200
        assert b'Invalid username or password' in response.data

class TestDashboard:
    """Test dashboard functionality."""
    
    def test_dashboard_requires_login(self, client):
        """Test that dashboard requires authentication."""
        response = client.get('/dashboard')
        assert response.status_code == 302
        assert '/login' in response.location
    
    def test_dashboard_loads_for_authenticated_user(self, authenticated_client):
        """Test that dashboard loads for authenticated user."""
        response = authenticated_client.get('/dashboard')
        assert response.status_code == 200
        assert b'Welcome, testuser!' in response.data
    
    def test_logout_functionality(self, authenticated_client):
        """Test logout functionality."""
        response = authenticated_client.get('/logout')
        assert response.status_code == 302
        assert '/login' in response.location
        
        # Verify user is logged out by trying to access dashboard
        response = authenticated_client.get('/dashboard')
        assert response.status_code == 302
        assert '/login' in response.location

class TestValidation:
    """Test validation functions."""
    
    def test_validate_email_valid(self):
        """Test email validation with valid emails."""
        valid_emails = [
            'test@example.com',
            'user.name@domain.co.uk',
            'firstname+lastname@company.org'
        ]
        for email in valid_emails:
            assert validate_email(email) == True
    
    def test_validate_email_invalid(self):
        """Test email validation with invalid emails."""
        invalid_emails = [
            'invalid-email',
            '@domain.com',
            'user@',
            'user@domain',
            ''
        ]
        for email in invalid_emails:
            assert validate_email(email) == False
    
    def test_validate_password_valid(self):
        """Test password validation with valid passwords."""
        valid_passwords = [
            'SecurePass123',
            'MyP@ssw0rd',
            'Complex1Password'
        ]
        for password in valid_passwords:
            is_valid, message = validate_password(password)
            assert is_valid == True
            assert message == "Password is valid"
    
    def test_validate_password_too_short(self):
        """Test password validation with short password."""
        is_valid, message = validate_password('Short1')
        assert is_valid == False
        assert "at least 8 characters" in message
    
    def test_validate_password_no_uppercase(self):
        """Test password validation without uppercase letter."""
        is_valid, message = validate_password('lowercase123')
        assert is_valid == False
        assert "uppercase letter" in message
    
    def test_validate_password_no_lowercase(self):
        """Test password validation without lowercase letter."""
        is_valid, message = validate_password('UPPERCASE123')
        assert is_valid == False
        assert "lowercase letter" in message
    
    def test_validate_password_no_number(self):
        """Test password validation without number."""
        is_valid, message = validate_password('NoNumbersHere')
        assert is_valid == False
        assert "number" in message

class TestFormValidation:
    """Test form validation and error handling."""
    
    def test_register_empty_fields(self, client):
        """Test registration with empty fields."""
        response = client.post('/register', data={})
        assert response.status_code == 200
        assert b'Please fill in all fields' in response.data
    
    def test_register_invalid_email(self, client):
        """Test registration with invalid email."""
        response = client.post('/register', data={
            'username': 'testuser',
            'email': 'invalid-email',
            'password': 'SecurePass123',
            'confirm_password': 'SecurePass123'
        })
        assert response.status_code == 200
        assert b'Please enter a valid email address' in response.data
    
    def test_register_weak_password(self, client):
        """Test registration with weak password."""
        response = client.post('/register', data={
            'username': 'testuser',
            'email': 'test@example.com',
            'password': 'weak',
            'confirm_password': 'weak'
        })
        assert response.status_code == 200
        assert b'Password must be at least 8 characters' in response.data
    
    def test_login_empty_fields(self, client):
        """Test login with empty fields."""
        response = client.post('/login', data={})
        assert response.status_code == 200
        assert b'Please fill in all fields' in response.data

class TestDatabaseOperations:
    """Test database operations."""
    
    def test_user_creation_and_retrieval(self, client):
        """Test that user is properly stored and retrieved from database."""
        # Register a user
        client.post('/register', data={
            'username': 'dbuser',
            'email': 'db@example.com',
            'password': 'DatabasePass123',
            'confirm_password': 'DatabasePass123'
        })
        
        # Verify user can login (which requires database retrieval)
        response = client.post('/login', data={
            'username': 'dbuser',
            'password': 'DatabasePass123'
        })
        assert response.status_code == 302
        assert '/dashboard' in response.location

class TestSecurity:
    """Test security features."""
    
    def test_password_hashing(self, client):
        """Test that passwords are properly hashed."""
        from werkzeug.security import check_password_hash
        import sqlite3
        
        # Register a user
        client.post('/register', data={
            'username': 'secureuser',
            'email': 'secure@example.com',
            'password': 'SecurePass123',
            'confirm_password': 'SecurePass123'
        })
        
        # Check that password is hashed in database
        conn = sqlite3.connect(app.config['DATABASE'])
        cursor = conn.cursor()
        cursor.execute('SELECT password_hash FROM users WHERE username = ?', ('secureuser',))
        result = cursor.fetchone()
        conn.close()
        
        assert result is not None
        password_hash = result[0]
        
        # Verify password is hashed (not stored in plain text)
        assert password_hash != 'SecurePass123'
        
        # Verify hash can be validated
        assert check_password_hash(password_hash, 'SecurePass123')
    
    def test_sql_injection_protection(self, client):
        """Test protection against SQL injection."""
        # Try SQL injection in login
        response = client.post('/login', data={
            'username': "admin'; DROP TABLE users; --",
            'password': 'anything'
        })
        
        # Should not crash and should show invalid login
        assert response.status_code == 200
        assert b'Invalid username or password' in response.data
        
        # Verify users table still exists by registering a new user
        response = client.post('/register', data={
            'username': 'testafter',
            'email': 'after@example.com',
            'password': 'TestPass123',
            'confirm_password': 'TestPass123'
        })
        assert response.status_code == 302

class TestIntegration:
    """Integration tests for complete user workflows."""
    
    def test_complete_user_journey(self, client):
        """Test complete user registration, login, and logout flow."""
        # 1. Start at index, should redirect to login
        response = client.get('/')
        assert response.status_code == 302
        assert '/login' in response.location
        
        # 2. Go to registration page
        response = client.get('/register')
        assert response.status_code == 200
        
        # 3. Register new user
        response = client.post('/register', data={
            'username': 'journeyuser',
            'email': 'journey@example.com',
            'password': 'JourneyPass123',
            'confirm_password': 'JourneyPass123'
        })
        assert response.status_code == 302
        assert '/login' in response.location
        
        # 4. Login with new user
        response = client.post('/login', data={
            'username': 'journeyuser',
            'password': 'JourneyPass123'
        })
        assert response.status_code == 302
        assert '/dashboard' in response.location
        
        # 5. Access dashboard
        response = client.get('/dashboard')
        assert response.status_code == 200
        assert b'Welcome, journeyuser!' in response.data
        
        # 6. Logout
        response = client.get('/logout')
        assert response.status_code == 302
        assert '/login' in response.location
        
        # 7. Verify cannot access dashboard after logout
        response = client.get('/dashboard')
        assert response.status_code == 302
        assert '/login' in response.location
