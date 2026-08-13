// public/js/main.js


/* =========================
   UTILITIES
   ========================= */

function formatDate(dateString) {
  return new Date(dateString).toLocaleDateString();
}

function createStarRating(rating) {
  let stars = '';
  for (let i = 1; i <= 5; i++) {
    stars += `<span class="${i <= rating ? 'text-warning' : 'text-muted'}">★</span>`;
  }
  return stars + `<small class="text-muted">(${rating}/5)</small>`;
}

/* =========================
   LOGIN LOGIC 
   ========================= */
document.addEventListener('DOMContentLoaded', () => {
  const loginForm = document.getElementById('loginForm');

  if (!loginForm) return;

  loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();

    const email = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value.trim();

    try{
      const response = await fetch('/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ email, password })
      });

      const data = await response.json();
      console.log('Login response:', data);

      if (data.success && data.redirectUrl){
        window.location.href = data.redirectUrl;
      } else {
        alert(data.message ||  'Login failed');
      }

    } catch(err){
      console.error('Login error:', err);
      alert('An error occurred during login');
    }
  });
});
