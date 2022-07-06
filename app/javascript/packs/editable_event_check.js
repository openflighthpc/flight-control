// start checking events at the start of the next minute
window.addEventListener('DOMContentLoaded', (event) => {
    if (editableRows().length !== 0) {
        let secs = new Date().getSeconds();
        setTimeout(editableCheck, 1000 );
        // setTimeout(editableCheck, (60-secs)*1000 );
    }
});

function editableCheck() {
    editableRows().each(function() {
        let uneditableTime = Number($(this).data('uneditable'));
        // check valid date
        if (new Date(uneditableTime) <= new Date()) {
            // event no longer editable
            $(this).removeClass('editable-event-row');
            // remove edit button
        }
    })
    if (editableRows().length !== 0) {
        console.log('timeout')
        // setTimeout(editableCheck,60000);
    }
}

function editableRows() {
    return $('.editable-event-row');
}