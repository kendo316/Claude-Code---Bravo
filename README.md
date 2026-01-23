# 🍸 Bravo Mood GIF - Real Housewives Edition 💎

Express your daily moods with iconic GIFs from Real Housewives and other Bravo shows! Perfect for sharing your feelings with friends in the most dramatic and fabulous way possible.

## Features

- **Text Input**: Describe your day or mood in your own words
- **Iconic Mood Selector**: Choose from pre-selected Real Housewives phrases like "Not well, bitch!" and "Gone with the wind fabulous"
- **Smart GIF Matching**: Automatically finds relevant Bravo and Real Housewives GIFs based on your input
- **Easy Sharing**: Share GIFs via native sharing (mobile) or copy to clipboard (desktop)
- **Download GIFs**: Save your favorite reactions
- **Mobile-First Design**: Optimized for smartphone browsers
- **Bravo-Themed UI**: Dramatic pink and purple gradients worthy of any Housewife

## Quick Start

### Option 1: Simple Demo Mode (No API Key Required)

1. Open `index.html` in your browser
2. The app will work with demo GIFs immediately

### Option 2: Full Giphy Integration (Recommended)

1. Get a free Giphy API key:
   - Go to [Giphy Developers](https://developers.giphy.com/)
   - Create an account
   - Create a new app and get your API key

2. Add your API key to `app.js`:
   ```javascript
   const GIPHY_API_KEY = 'your_actual_api_key_here';
   ```

3. Open `index.html` in your browser

## Usage

### For Personal Use
Simply open `index.html` in any modern browser on your phone or computer.

### For Sharing with Friends
Deploy to any static hosting service:

**GitHub Pages** (Free & Easy):
1. Push this repository to GitHub
2. Go to Settings > Pages
3. Select your branch and save
4. Share the URL with your friends

**Netlify** (Free & Easy):
1. Drag and drop the folder to [netlify.com](https://netlify.com)
2. Get an instant URL to share

**Vercel** (Free):
1. Install Vercel CLI: `npm i -g vercel`
2. Run `vercel` in this directory
3. Follow the prompts

## How It Works

1. **Enter your mood**: Type how you're feeling or select an iconic Bravo phrase
2. **Get your GIF**: Click "Get My GIF" to find the perfect reaction
3. **Share**: Use the share button to send to your group chat
4. **Download**: Save GIFs for later use

## Customization

### Adding More Mood Phrases

Edit the `<select>` element in `index.html` to add more iconic Bravo moments:

```html
<option value="real housewives your-search-term">Your Phrase Here</option>
```

### Changing Colors

Edit CSS variables in `styles.css`:

```css
:root {
    --bravo-pink: #ff1493;
    --bravo-gold: #ffd700;
    --bravo-purple: #9370db;
}
```

### Filtering GIF Results

Modify the search parameters in `app.js`:

```javascript
const params = new URLSearchParams({
    api_key: GIPHY_API_KEY,
    q: query,
    limit: 25,          // Number of GIFs to choose from
    rating: 'pg-13',    // Content rating
    lang: 'en'
});
```

## Technical Details

- **No Build Process**: Pure HTML, CSS, and JavaScript
- **No Dependencies**: Works without npm or bundlers
- **Responsive**: Mobile-first with desktop support
- **Modern Browser Features**: Uses Web Share API, Fetch API, and modern CSS
- **Graceful Fallbacks**: Works in older browsers with reduced functionality

## Browser Support

- **Modern Mobile Browsers**: Full support (iOS Safari, Chrome, Samsung Internet)
- **Desktop Browsers**: Full support (Chrome, Firefox, Safari, Edge)
- **Older Browsers**: Basic functionality with reduced features

## Privacy & Data

- No user data is collected or stored
- All GIF searches go directly to Giphy's API
- No cookies or tracking
- No server-side code

## Future Enhancements

Potential features to add:
- Favorite GIFs collection (localStorage)
- Dark mode toggle
- More Bravo show categories (Vanderpump Rules, Summer House, etc.)
- Custom mood phrase creation
- GIF history
- Social media direct sharing integrations

## Credits

- GIFs powered by [Giphy](https://giphy.com)
- Inspired by the fabulous cast of Real Housewives and Bravo shows
- Built with love for Bravo fans everywhere

## License

Free to use for personal projects. If using commercially, ensure you comply with Giphy's terms of service.

---

Made with 💎 for Bravo fans • Not affiliated with Bravo or NBCUniversal
