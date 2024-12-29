const imageFolder = 'images'; // Folder where your assets are stored
const totalImages = 80; // Total number of items
const imageGrid = document.getElementById('imageGrid');
const lightbox = document.getElementById('lightbox');
const lightboxImage = document.getElementById('lightboxImage');
const closeLightbox = document.getElementById('closeLightbox');

// Dynamically generate grid elements
for (let i = 1; i <= totalImages; i++) {
    let element;
    let extension;

    // Determine the placeholder file extension (png for videos)
    if (i === 11 || i === 14 || i === 70) {
        extension = 'gif'; // GIF replacements
    } else {
        extension = 'png';
    }

    element = document.createElement('img');
    element.src = `${imageFolder}/${i}.${extension}`;
    element.alt = `Image ${i}`;
    element.loading = 'lazy'; // Add lazy loading
    element.classList.add('grid-item'); // Optional: Add a class for styling

    // Add click event to open the lightbox
    element.addEventListener('click', () => {
        if (i === 57 || i === 73) {
            openLightbox(i, 'mp4'); // Open video in lightbox
        } else {
            openLightbox(i, extension); // Open image in lightbox
        }
    });

    // Append the element to the grid
    imageGrid.appendChild(element);
}

// Open the lightbox with the appropriate content
function openLightbox(index, extension) {
    // If it's a video, replace the image element with a video element
    if (extension === 'mp4') {
        const videoElement = document.createElement('video');
        videoElement.src = `${imageFolder}/${index}.mp4`;
        videoElement.controls = true;
        videoElement.autoplay = true;
        videoElement.style.maxWidth = '90%';
        videoElement.style.maxHeight = '90%';

        lightboxImage.replaceWith(videoElement);
        lightboxImage.id = ''; // Reset the ID of the old element
        videoElement.id = 'lightboxImage'; // Set the ID for the new element
    } else {
        // Handle image cases (.png or .gif)
        lightboxImage.src = `${imageFolder}/${index}.${extension}`;
        if (lightboxImage.tagName !== 'IMG') {
            const imgElement = document.createElement('img');
            imgElement.src = `${imageFolder}/${index}.${extension}`;
            imgElement.id = 'lightboxImage';
            lightbox.appendChild(imgElement);
        }
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
    
    // Check if the lightbox content is a video
    if (lightboxImage.tagName === 'VIDEO') {
        lightboxImage.pause(); // Pause the video
        lightboxImage.currentTime = 0; // Reset playback to the start
        lightboxImage.remove(); // Remove the video element

        // Replace with a placeholder image element
        const imgPlaceholder = document.createElement('img');
        imgPlaceholder.id = 'lightboxImage';
        imgPlaceholder.alt = 'Expanded view';
        lightbox.appendChild(imgPlaceholder); // Restore placeholder image element
    }
}
