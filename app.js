// Bravo Mood GIF App
// Real Housewives Edition

// Giphy API Configuration
const GIPHY_API_KEY = 'your_api_key_here'; // Users should get their own key from developers.giphy.com
const GIPHY_BASE_URL = 'https://api.giphy.com/v1/gifs';

// Demo mode fallback GIFs (Bravo-themed) if API key is not set
const DEMO_GIFS = [
    'https://media.giphy.com/media/1Z02vuppxP1Pa/giphy.gif',
    'https://media.giphy.com/media/l0CLTQeZrFWmMxIWc/giphy.gif',
    'https://media.giphy.com/media/DIgqIAIjBqKlYPp0AK/giphy.gif',
    'https://media.giphy.com/media/SrDsJj5i1Chm8/giphy.gif',
    'https://media.giphy.com/media/xTiTnGQBF0vfpfPEg8/giphy.gif'
];

// State
let currentGifUrl = '';
let currentSearchQuery = '';

// DOM Elements
const moodTextArea = document.getElementById('mood-text');
const moodDropdown = document.getElementById('mood-dropdown');
const generateBtn = document.getElementById('generate-btn');
const loadingSection = document.getElementById('loading');
const resultSection = document.getElementById('result-section');
const gifImage = document.getElementById('gif-image');
const shareBtn = document.getElementById('share-btn');
const downloadBtn = document.getElementById('download-btn');
const newGifBtn = document.getElementById('new-gif-btn');
const charCounter = document.getElementById('char-counter');

// Event Listeners
moodTextArea.addEventListener('input', updateCharCounter);
moodDropdown.addEventListener('change', handleMoodSelection);
generateBtn.addEventListener('click', handleGenerateGif);
shareBtn.addEventListener('click', handleShare);
downloadBtn.addEventListener('click', handleDownload);
newGifBtn.addEventListener('click', resetApp);

// Character counter
function updateCharCounter() {
    const count = moodTextArea.value.length;
    charCounter.textContent = count;

    if (count > 180) {
        charCounter.style.color = '#ff1493';
    } else {
        charCounter.style.color = '#666';
    }
}

// Handle mood selection from dropdown
function handleMoodSelection() {
    if (moodDropdown.value) {
        // Clear text area when dropdown is selected
        moodTextArea.value = '';
        updateCharCounter();
    }
}

// Main function to generate GIF
async function handleGenerateGif() {
    const textInput = moodTextArea.value.trim();
    const moodSelection = moodDropdown.value;

    // Validate input
    if (!textInput && !moodSelection) {
        alert('Please enter how you\'re feeling or select a mood! 💅');
        return;
    }

    // Disable button and show loading
    generateBtn.disabled = true;
    resultSection.classList.add('hidden');
    loadingSection.classList.remove('hidden');

    try {
        // Determine search query
        currentSearchQuery = moodSelection || textInput;

        // Always add Bravo-related terms to search
        const bravoTerms = ['real housewives', 'bravo', 'housewives'];
        let searchQuery = currentSearchQuery;

        // If using dropdown, use the pre-configured search term
        // If using text input, try to match sentiment and add bravo context
        if (!moodSelection) {
            searchQuery = `${textInput} ${bravoTerms[Math.floor(Math.random() * bravoTerms.length)]}`;
        }

        // Fetch GIF
        const gifUrl = await fetchGif(searchQuery);

        // Display result
        displayGif(gifUrl);

    } catch (error) {
        console.error('Error fetching GIF:', error);
        alert('Oops! Something went wrong. Try again, sweetie! 💎');
        resetToInput();
    }
}

// Fetch GIF from Giphy API
async function fetchGif(query) {
    // Check if API key is set
    if (GIPHY_API_KEY === 'your_api_key_here') {
        console.warn('Giphy API key not set. Using demo mode.');
        return getDemoGif();
    }

    try {
        // Use Giphy search endpoint
        const endpoint = `${GIPHY_BASE_URL}/search`;
        const params = new URLSearchParams({
            api_key: GIPHY_API_KEY,
            q: query,
            limit: 25,
            rating: 'pg-13',
            lang: 'en'
        });

        const response = await fetch(`${endpoint}?${params}`);

        if (!response.ok) {
            throw new Error('Giphy API request failed');
        }

        const data = await response.json();

        // Check if we got results
        if (!data.data || data.data.length === 0) {
            // Fallback to a more general Bravo search
            return await fetchGif('real housewives');
        }

        // Pick a random GIF from results
        const randomIndex = Math.floor(Math.random() * data.data.length);
        const gif = data.data[randomIndex];

        return gif.images.original.url;

    } catch (error) {
        console.error('Giphy API error:', error);
        // Fallback to demo mode
        return getDemoGif();
    }
}

// Get a random demo GIF (fallback)
function getDemoGif() {
    const randomIndex = Math.floor(Math.random() * DEMO_GIFS.length);
    return DEMO_GIFS[randomIndex];
}

// Display the GIF
function displayGif(gifUrl) {
    currentGifUrl = gifUrl;
    gifImage.src = gifUrl;
    gifImage.alt = `Bravo GIF for: ${currentSearchQuery}`;

    loadingSection.classList.add('hidden');
    resultSection.classList.remove('hidden');
    generateBtn.disabled = false;

    // Scroll to result
    resultSection.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

// Handle sharing
async function handleShare() {
    const shareText = `Check out my mood! 🍸\n${currentSearchQuery}`;

    // Check if Web Share API is available (mobile browsers)
    if (navigator.share) {
        try {
            await navigator.share({
                title: 'My Bravo Mood',
                text: shareText,
                url: currentGifUrl
            });
        } catch (error) {
            if (error.name !== 'AbortError') {
                // Fallback to copy to clipboard
                copyToClipboard();
            }
        }
    } else {
        // Fallback for desktop
        copyToClipboard();
    }
}

// Copy GIF URL to clipboard
function copyToClipboard() {
    const textToCopy = `${currentSearchQuery}\n${currentGifUrl}`;

    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(textToCopy)
            .then(() => {
                showNotification('GIF link copied! Share away! 💅');
            })
            .catch(() => {
                showNotification('Please manually copy the GIF by long-pressing on it');
            });
    } else {
        // Fallback for older browsers
        const textArea = document.createElement('textarea');
        textArea.value = textToCopy;
        textArea.style.position = 'fixed';
        textArea.style.left = '-999999px';
        document.body.appendChild(textArea);
        textArea.select();

        try {
            document.execCommand('copy');
            showNotification('GIF link copied! Share away! 💅');
        } catch (error) {
            showNotification('Please manually copy the GIF by long-pressing on it');
        }

        document.body.removeChild(textArea);
    }
}

// Show notification
function showNotification(message) {
    // Create notification element
    const notification = document.createElement('div');
    notification.textContent = message;
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        left: 50%;
        transform: translateX(-50%);
        background: linear-gradient(135deg, #ff1493 0%, #9370db 100%);
        color: white;
        padding: 1rem 2rem;
        border-radius: 12px;
        box-shadow: 0 8px 16px rgba(0, 0, 0, 0.2);
        z-index: 1000;
        animation: slideDown 0.3s ease;
        font-weight: 600;
        max-width: 90%;
        text-align: center;
    `;

    document.body.appendChild(notification);

    // Remove after 3 seconds
    setTimeout(() => {
        notification.style.animation = 'fadeOut 0.3s ease';
        setTimeout(() => {
            document.body.removeChild(notification);
        }, 300);
    }, 3000);
}

// Add animation styles
const style = document.createElement('style');
style.textContent = `
    @keyframes slideDown {
        from {
            opacity: 0;
            transform: translate(-50%, -20px);
        }
        to {
            opacity: 1;
            transform: translate(-50%, 0);
        }
    }

    @keyframes fadeOut {
        to {
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);

// Handle download
async function handleDownload() {
    try {
        // Fetch the GIF as a blob
        const response = await fetch(currentGifUrl);
        const blob = await response.blob();

        // Create download link
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `bravo-mood-${Date.now()}.gif`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);

        showNotification('GIF downloaded! 💎');
    } catch (error) {
        console.error('Download error:', error);
        // Fallback: open in new tab
        window.open(currentGifUrl, '_blank');
        showNotification('Opening GIF in new tab...');
    }
}

// Reset app to initial state
function resetApp() {
    moodTextArea.value = '';
    moodDropdown.value = '';
    updateCharCounter();
    resultSection.classList.add('hidden');
    currentGifUrl = '';
    currentSearchQuery = '';

    // Scroll to top
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

// Reset to input view
function resetToInput() {
    loadingSection.classList.add('hidden');
    generateBtn.disabled = false;
}

// Initialize app
console.log('🍸 Bravo Mood GIF App Loaded! 💎');
console.log('Get your Giphy API key at: https://developers.giphy.com/');
