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

// Mood analysis mapping - keywords to Bravo search terms
const MOOD_KEYWORDS = {
    fabulous: {
        keywords: ['amazing', 'great', 'awesome', 'wonderful', 'fantastic', 'perfect', 'best', 'love', 'happy', 'excited', 'celebration', 'win', 'won', 'success', 'promoted', 'raise', 'blessed', 'grateful'],
        searches: ['real housewives fabulous', 'real housewives celebration', 'real housewives champagne', 'real housewives dancing']
    },
    sassy: {
        keywords: ['whatever', 'please', 'seriously', 'really', 'ok', 'sure', 'right', 'obvious', 'duh', 'clearly'],
        searches: ['real housewives eye roll', 'real housewives sassy', 'real housewives attitude', 'real housewives smirk']
    },
    dramatic: {
        keywords: ['cannot', 'believe', 'shocked', 'surprised', 'wow', 'omg', 'crazy', 'insane', 'wild', 'unbelievable', 'dramatic'],
        searches: ['real housewives shocked', 'real housewives gasp', 'real housewives dramatic', 'real housewives stunned']
    },
    overit: {
        keywords: ['annoying', 'irritating', 'frustrating', 'tired', 'exhausted', 'done', 'over', 'enough', 'stop', 'quit', 'leave', 'bye'],
        searches: ['real housewives done', 'real housewives over it', 'real housewives eye roll', 'real housewives bye']
    },
    angry: {
        keywords: ['angry', 'mad', 'furious', 'pissed', 'hate', 'terrible', 'worst', 'awful', 'horrible', 'annoyed', 'upset'],
        searches: ['real housewives angry', 'real housewives fight', 'real housewives mad', 'real housewives yelling']
    },
    confused: {
        keywords: ['confused', 'what', 'why', 'how', 'huh', 'understand', 'make sense', 'unclear', 'lost'],
        searches: ['real housewives confused', 'real housewives what', 'real housewives huh', 'real housewives question']
    },
    supportive: {
        keywords: ['proud', 'support', 'congrats', 'congratulations', 'good job', 'well done', 'you got this', 'believe'],
        searches: ['real housewives cheers', 'real housewives hug', 'real housewives support', 'real housewives proud']
    },
    shady: {
        keywords: ['shady', 'side eye', 'suspicious', 'hmm', 'interesting', 'tea', 'gossip', 'rumor', 'heard'],
        searches: ['real housewives side eye', 'real housewives shade', 'real housewives smirk', 'real housewives tea']
    }
};

// Housewives data for randomizer
const HOUSEWIVES = [
    { name: 'Teresa Giudice', show: 'RHONJ', energy: 'Table-flipping passion' },
    { name: 'Nene Leakes', show: 'RHOA', energy: 'Bloop energy' },
    { name: 'Ramona Singer', show: 'RHONY', energy: 'Turtle time vibes' },
    { name: 'Lisa Vanderpump', show: 'RHOBH', energy: 'British elegance' },
    { name: 'Bethenny Frankel', show: 'RHONY', energy: 'Mention it all' },
    { name: 'Kenya Moore', show: 'RHOA', energy: 'Gone with the wind' },
    { name: 'Kyle Richards', show: 'RHOBH', energy: 'Beverly Hills drama' },
    { name: 'Dorinda Medley', show: 'RHONY', energy: 'I made it nice!' },
    { name: 'Phaedra Parks', show: 'RHOA', energy: 'Southern belle sass' },
    { name: 'Sonja Morgan', show: 'RHONY', energy: 'Tipsy elegance' },
    { name: 'Kim Richards', show: 'RHOBH', energy: 'Let\'s talk about it' },
    { name: 'Gizelle Bryant', show: 'RHOP', energy: 'Word on the street' },
    { name: 'Jen Shah', show: 'RHOSLC', energy: 'Shah squad energy' }
];

// State
let currentGifUrl = '';
let currentSearchQuery = '';
let recentGifs = []; // Track recently shown GIFs to avoid repetition
const MAX_RECENT_GIFS = 15; // Remember last 15 GIFs
let currentFranchise = 'all'; // Current franchise filter
let currentHousewife = null; // Currently channeling housewife
let favorites = []; // Favorite GIFs

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
const favoriteBtn = document.getElementById('favorite-btn');
const favoritesSection = document.getElementById('favorites-section');
const toggleFavoritesBtn = document.getElementById('toggle-favorites-btn');
const favoritesGallery = document.getElementById('favorites-gallery');
const favoritesCount = document.getElementById('favorites-count');
const channelHousewifeBtn = document.getElementById('channel-housewife-btn');
const currentHousewifeDisplay = document.getElementById('current-housewife');
const filterButtons = document.querySelectorAll('.filter-btn');

// Event Listeners
moodTextArea.addEventListener('input', updateCharCounter);
moodDropdown.addEventListener('change', handleMoodSelection);
generateBtn.addEventListener('click', handleGenerateGif);
shareBtn.addEventListener('click', handleShare);
downloadBtn.addEventListener('click', handleDownload);
newGifBtn.addEventListener('click', resetApp);
favoriteBtn.addEventListener('click', toggleFavorite);
toggleFavoritesBtn.addEventListener('click', toggleFavoritesGallery);
channelHousewifeBtn.addEventListener('click', channelRandomHousewife);
filterButtons.forEach(btn => btn.addEventListener('click', handleFranchiseFilter));

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

// Analyze text input to determine mood category
function analyzeMood(text) {
    const lowerText = text.toLowerCase();
    let bestMatch = null;
    let highestScore = 0;

    // Check each mood category for keyword matches
    for (const [mood, data] of Object.entries(MOOD_KEYWORDS)) {
        let score = 0;
        for (const keyword of data.keywords) {
            if (lowerText.includes(keyword)) {
                score++;
            }
        }

        if (score > highestScore) {
            highestScore = score;
            bestMatch = mood;
        }
    }

    // If we found a match, return a search term from that category
    if (bestMatch && highestScore > 0) {
        const searches = MOOD_KEYWORDS[bestMatch].searches;
        return searches[Math.floor(Math.random() * searches.length)];
    }

    // Default fallback - just use general Real Housewives search
    return 'real housewives reaction';
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
        let searchQuery;

        // If using dropdown, use the pre-configured search term
        if (moodSelection) {
            searchQuery = moodSelection;
            currentSearchQuery = moodDropdown.options[moodDropdown.selectedIndex].text;
        } else {
            // Analyze the text input to find matching Bravo mood
            searchQuery = analyzeMood(textInput);
            currentSearchQuery = textInput;
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

// Shuffle array for better randomization
function shuffleArray(array) {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}

// Check if GIF is Bravo-related
function isBravoGif(gif) {
    const bravoKeywords = ['housewives', 'bravo', 'rhony', 'rhobh', 'rhoa', 'rhonj', 'rhoc', 'rhop', 'rhoslc', 'vanderpump', 'southern charm', 'below deck'];
    const title = (gif.title || '').toLowerCase();
    const slug = (gif.slug || '').toLowerCase();
    const username = (gif.username || '').toLowerCase();

    // Check if title, slug, or username contains Bravo keywords
    return bravoKeywords.some(keyword =>
        title.includes(keyword) || slug.includes(keyword) || username.includes(keyword)
    );
}

// Fetch GIF from Giphy API
async function fetchGif(query) {
    // Check if API key is set
    if (GIPHY_API_KEY === 'your_api_key_here') {
        console.warn('Giphy API key not set. Using demo mode.');
        return getDemoGif();
    }

    try {
        // Add random offset for more variety (0-50)
        const randomOffset = Math.floor(Math.random() * 50);

        // Use Giphy search endpoint
        const endpoint = `${GIPHY_BASE_URL}/search`;
        const params = new URLSearchParams({
            api_key: GIPHY_API_KEY,
            q: query,
            limit: 50, // Get more results to filter from
            offset: randomOffset, // Add variety by starting at different positions
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

        // Filter for Bravo-only GIFs
        let bravoGifs = data.data.filter(gif => isBravoGif(gif));

        // If we have Bravo GIFs, use them. Otherwise use all results.
        let gifsToUse = bravoGifs.length > 0 ? bravoGifs : data.data;

        // Filter out recently shown GIFs
        gifsToUse = gifsToUse.filter(gif => !recentGifs.includes(gif.images.original.url));

        // If we filtered out all GIFs, clear recent history and try again
        if (gifsToUse.length === 0) {
            console.log('All GIFs were recent, clearing history');
            recentGifs = [];
            gifsToUse = bravoGifs.length > 0 ? bravoGifs : data.data;
        }

        // Shuffle for better randomization
        const shuffledGifs = shuffleArray(gifsToUse);

        // Pick the first GIF from shuffled results
        const gif = shuffledGifs[0];
        const gifUrl = gif.images.original.url;

        // Add to recent GIFs history
        recentGifs.push(gifUrl);

        // Keep only the last MAX_RECENT_GIFS
        if (recentGifs.length > MAX_RECENT_GIFS) {
            recentGifs.shift(); // Remove oldest
        }

        return gifUrl;

    } catch (error) {
        console.error('Giphy API error:', error);
        // Fallback to demo mode
        return getDemoGif();
    }
}

// Get a random demo GIF (fallback)
function getDemoGif() {
    // Filter out recently shown demo GIFs
    let availableGifs = DEMO_GIFS.filter(gif => !recentGifs.includes(gif));

    // If all have been shown recently, reset and use all
    if (availableGifs.length === 0) {
        recentGifs = [];
        availableGifs = DEMO_GIFS;
    }

    // Shuffle and pick first
    const shuffled = shuffleArray(availableGifs);
    const gifUrl = shuffled[0];

    // Add to history
    recentGifs.push(gifUrl);
    if (recentGifs.length > MAX_RECENT_GIFS) {
        recentGifs.shift();
    }

    return gifUrl;
}

// Display the GIF
function displayGif(gifUrl) {
    currentGifUrl = gifUrl;
    gifImage.src = gifUrl;
    gifImage.alt = `Bravo GIF for: ${currentSearchQuery}`;

    loadingSection.classList.add('hidden');
    resultSection.classList.remove('hidden');
    generateBtn.disabled = false;

    // Update favorite button state
    updateFavoriteButton();

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

// ============ FAVORITES SYSTEM ============

// Load favorites from localStorage
function loadFavorites() {
    try {
        const stored = localStorage.getItem('bravo-favorites');
        favorites = stored ? JSON.parse(stored) : [];
        updateFavoritesDisplay();
    } catch (error) {
        console.error('Error loading favorites:', error);
        favorites = [];
    }
}

// Save favorites to localStorage
function saveFavorites() {
    try {
        localStorage.setItem('bravo-favorites', JSON.stringify(favorites));
    } catch (error) {
        console.error('Error saving favorites:', error);
    }
}

// Toggle favorite status
function toggleFavorite() {
    if (!currentGifUrl) return;

    const index = favorites.findIndex(fav => fav.url === currentGifUrl);

    if (index > -1) {
        // Remove from favorites
        favorites.splice(index, 1);
        showNotification('Removed from favorites');
    } else {
        // Add to favorites
        favorites.push({
            url: currentGifUrl,
            query: currentSearchQuery,
            timestamp: Date.now()
        });
        showNotification('Added to favorites! 💎');
    }

    saveFavorites();
    updateFavoriteButton();
    updateFavoritesDisplay();
}

// Update favorite button appearance
function updateFavoriteButton() {
    const isFavorited = favorites.some(fav => fav.url === currentGifUrl);
    if (isFavorited) {
        favoriteBtn.classList.add('favorited');
        favoriteBtn.querySelector('.heart').textContent = '♥';
    } else {
        favoriteBtn.classList.remove('favorited');
        favoriteBtn.querySelector('.heart').textContent = '♡';
    }
}

// Toggle favorites gallery visibility
function toggleFavoritesGallery() {
    const isHidden = favoritesGallery.classList.contains('hidden');
    if (isHidden) {
        favoritesGallery.classList.remove('hidden');
        toggleFavoritesBtn.textContent = `Hide Favorites (${favorites.length})`;
    } else {
        favoritesGallery.classList.add('hidden');
        toggleFavoritesBtn.textContent = `Show Favorites (${favorites.length})`;
    }
}

// Update favorites display
function updateFavoritesDisplay() {
    favoritesCount.textContent = favorites.length;

    if (favorites.length === 0) {
        favoritesSection.classList.add('hidden');
        favoritesGallery.innerHTML = '<p class="empty-favorites">No favorites yet! Heart a GIF to save it here.</p>';
        return;
    }

    favoritesSection.classList.remove('hidden');

    // Sort by most recent first
    const sortedFavorites = [...favorites].sort((a, b) => b.timestamp - a.timestamp);

    favoritesGallery.innerHTML = sortedFavorites.map((fav, index) => `
        <div class="favorite-item" data-url="${fav.url}" data-query="${fav.query}">
            <img src="${fav.url}" alt="${fav.query}">
            <button class="remove-favorite" data-index="${index}" aria-label="Remove favorite">×</button>
        </div>
    `).join('');

    // Add event listeners to favorite items
    document.querySelectorAll('.favorite-item').forEach(item => {
        item.addEventListener('click', (e) => {
            if (!e.target.classList.contains('remove-favorite')) {
                currentGifUrl = item.dataset.url;
                currentSearchQuery = item.dataset.query;
                displayGif(currentGifUrl);
            }
        });
    });

    // Add event listeners to remove buttons
    document.querySelectorAll('.remove-favorite').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const url = btn.parentElement.dataset.url;
            favorites = favorites.filter(fav => fav.url !== url);
            saveFavorites();
            updateFavoritesDisplay();
            showNotification('Removed from favorites');
        });
    });
}

// ============ FRANCHISE FILTERS ============

// Handle franchise filter selection
function handleFranchiseFilter(e) {
    const franchise = e.target.dataset.franchise;
    currentFranchise = franchise;

    // Update active state
    filterButtons.forEach(btn => btn.classList.remove('active'));
    e.target.classList.add('active');

    showNotification(`Filtering by ${franchise === 'all' ? 'All Bravo' : franchise.toUpperCase()}`);
}

// ============ HOUSEWIFE RANDOMIZER ============

// Channel a random housewife
function channelRandomHousewife() {
    const randomHousewife = HOUSEWIVES[Math.floor(Math.random() * HOUSEWIVES.length)];
    currentHousewife = randomHousewife;

    currentHousewifeDisplay.textContent = `Channeling ${randomHousewife.name} from ${randomHousewife.show} — ${randomHousewife.energy}`;
    currentHousewifeDisplay.classList.remove('hidden');

    showNotification(`You're channeling ${randomHousewife.name}!`);
}

// ============ UPDATE FETCH GIF WITH FILTERS ============

// Update isBravoGif to respect franchise filter
const originalIsBravoGif = isBravoGif;
function isBravoGif(gif) {
    // First check if it's Bravo-related at all
    if (!originalIsBravoGif(gif)) {
        return false;
    }

    // If filtering by specific franchise
    if (currentFranchise !== 'all') {
        const title = (gif.title || '').toLowerCase();
        const slug = (gif.slug || '').toLowerCase();
        const franchiseKey = currentFranchise.toLowerCase();
        return title.includes(franchiseKey) || slug.includes(franchiseKey);
    }

    return true;
}

// Update analyzeMood to consider current housewife
const originalAnalyzeMood = analyzeMood;
function analyzeMood(text) {
    // If channeling a housewife, incorporate their name in search
    if (currentHousewife) {
        const baseSearch = originalAnalyzeMood(text);
        return `${baseSearch} ${currentHousewife.name}`;
    }
    return originalAnalyzeMood(text);
}

// Initialize app
loadFavorites();
console.log('🍸 Bravo Mood GIF App Loaded! 💎');
console.log('Get your Giphy API key at: https://developers.giphy.com/');
