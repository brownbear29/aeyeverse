const imageFolder = 'images'; // Folder where your assets are stored
const totalImages = 80; // Total number of items
const imageGrid = document.getElementById('imageGrid');
const lightbox = document.getElementById('lightbox');
const closeLightbox = document.getElementById('closeLightbox');

// Dynamically generate grid elements
for (let i = 1; i <= totalImages; i++) {
    let element;
    let extension;
    let gridItem;

    // Determine the file extension
    if (i === 57 || i === 73) {
        extension = 'png'; // Use PNG placeholders for videos
        gridItem = document.createElement('div');
        gridItem.classList.add('video-container'); // Add a container for overlay
    } else if (i === 11 || i === 14 || i === 70) {
        extension = 'gif'; // GIF replacements
        gridItem = document.createElement('div');
    } else {
        extension = 'png';
        gridItem = document.createElement('div');
    }

    element = document.createElement('img');
    element.src = `${imageFolder}/${i}.${extension}`; // Set the image source
    element.alt = `Image ${i}`; // Set the alt text (for accessibility)
    element.loading = 'lazy'; // Enable native lazy loading
    element.classList.add('grid-item'); // Optional: Add a class for styling

    if (i === 57 || i === 73) {
        // Add the overlay and play icon for video placeholders
        const overlay = document.createElement('div');
        overlay.classList.add('overlay');
        const playIcon = document.createElement('span');
        playIcon.classList.add('play-icon');
        playIcon.textContent = '▶'; // Play icon (you can use an icon library for better visuals)
        overlay.appendChild(playIcon);
        gridItem.appendChild(overlay);
    }

    // Add click event to open the lightbox
    element.addEventListener('click', () => {
        if (i === 57 || i === 73) {
            openLightbox(i, 'mp4'); // Open video in lightbox
        } else {
            openLightbox(i, extension); // Open image in lightbox
        }
    });

    // Append the image to the grid container (with overlay if video)
    gridItem.appendChild(element);
    imageGrid.appendChild(gridItem);
}

function openLightbox(index, extension) {
    // Remove previous content (if any) in the lightbox
    const existingContent = lightbox.querySelector('.lightbox-content');
    if (existingContent) {
        existingContent.remove();
    }

    // Create a new content container for the lightbox
    const contentContainer = document.createElement('div');
    contentContainer.classList.add('lightbox-content');
    lightbox.appendChild(contentContainer);

    // Create a container for media and overlay
    const mediaContainer = document.createElement('div');
    mediaContainer.classList.add('lightbox-media');
    contentContainer.appendChild(mediaContainer);

    // Fetch metadata
    fetch(`metadata/${index}.json`)
        .then((response) => response.json())
        .then((data) => {
            // Add overlay title
            const titleOverlay = document.createElement('div');
            titleOverlay.textContent = data.name || 'No Title';
            titleOverlay.classList.add('lightbox-overlay', 'lightbox-title-overlay');
            mediaContainer.appendChild(titleOverlay);

            // Add overlay description
            if (data.description && data.description.trim()) {
                const descriptionOverlay = document.createElement('div');
                descriptionOverlay.innerHTML = parseMarkdown(data.description); // Use parseMarkdown for formatting
                descriptionOverlay.classList.add('lightbox-overlay', 'lightbox-description-overlay');
                mediaContainer.appendChild(descriptionOverlay);
            }
        })
        .catch((error) => {
            console.error(`Error fetching metadata for ${index}:`, error);

            // Fallback title overlay
            const titleOverlay = document.createElement('div');
            titleOverlay.textContent = 'No Title';
            titleOverlay.classList.add('lightbox-overlay', 'lightbox-title-overlay');
            mediaContainer.appendChild(titleOverlay);
    });


    // Handle video
    if (extension === 'mp4') {
        const videoElement = document.createElement('video');
        videoElement.src = `${imageFolder}/${index}.mp4`;
        videoElement.controls = true;
        videoElement.autoplay = true;
        videoElement.style.maxWidth = '100%';
        videoElement.style.maxHeight = '90vh';
        videoElement.style.objectFit = 'contain';
        mediaContainer.appendChild(videoElement);
    } else {
        // Handle image
        const imgElement = document.createElement('img');
        imgElement.src = `${imageFolder}/${index}.${extension}`;
        imgElement.alt = ''; // No alt text for lightbox images
        imgElement.style.maxWidth = '100%';
        imgElement.style.maxHeight = '90vh';
        imgElement.style.objectFit = 'contain';
        mediaContainer.appendChild(imgElement);
    }

    lightbox.style.display = 'flex';
}

// Close the lightbox when the close button is clicked
closeLightbox.addEventListener('click', closeLightboxHandler);

// Close the lightbox when clicking outside the content
lightbox.addEventListener('click', (e) => {
    if (e.target === lightbox) {
        closeLightboxHandler();
    }
});

function closeLightboxHandler() {
    lightbox.style.display = 'none';
    const videoElement = lightbox.querySelector('video');
    if (videoElement) {
        videoElement.pause(); // Pause the video
        videoElement.currentTime = 0; // Reset playback to the start
    }
}

// Function to parse basic Markdown
function parseMarkdown(markdown) {
    if (!markdown) return '';
    // Replace \n with <br> for line breaks
    let html = markdown.replace(/\\n/g, '<br>');
    // Convert Markdown links [text](url) to <a> tags
    html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');
    return html;
}
