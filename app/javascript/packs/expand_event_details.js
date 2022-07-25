window.addEventListener('DOMContentLoaded', (event) => {
    $("td[colspan=7]").find("div").hide();
    $(".view-button").click( function(event) {
        event.stopPropagation();
        let $target = $(event.target);
        if ($target.hasClass('view-button')) {
            let nextRow = $target.closest("tr").next().find("div");
            nextRow.slideToggle('fast');
        }
    })
})
