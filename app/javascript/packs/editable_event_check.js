window.addEventListener('DOMContentLoaded', (event) => {
    if (editableRows().length > 0) {
        // start checking events at the start of the next minute
        let secs = new Date().getSeconds();
        setTimeout(editableCheck, (60-secs)*1000 );
    }
});

function editableCheck() {
    // remove edit icons for events that have become uneditable
    editableRows().forEach(function(event) {
        let uneditableTime = validateTime(Number(event.dataset.uneditable));
        if (uneditableTime <= new Date()) {
            event.classList.remove('editable-event-row');
            let icon = event.querySelector('.fa-pencil')
            icon.style.display = 'none'
        }
    })
    // check events again each minute
    if (editableRows().length > 0) {
        setTimeout(editableCheck,60000);
    }
}

function editableRows() {
    return document.querySelectorAll('.editable-event-row');
}

function validateTime(uneditableTime) {
    let dateTime = new Date(uneditableTime);
    if (uneditableTime === 0 || uneditableTime == null || isNaN(dateTime)) {
        throw 'Invalid time given for when event is no longer editable.';
    }
    return dateTime
}
