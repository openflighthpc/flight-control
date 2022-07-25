window.addEventListener('DOMContentLoaded', (event) => {
    $("td[colspan=7]").find("div").hide();
    $("table").click(function(event) {
        event.stopPropagation();
        var $target = $(event.target);
        if ($target.hasClass('view-button')) {
            $target.closest("tr").next().find("div").slideToggle('fast', 'swing');
        };
    });
})
