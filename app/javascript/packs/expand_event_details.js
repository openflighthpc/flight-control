window.addEventListener('DOMContentLoaded', (event) => {
    $("td[colspan=7]").find("div").hide();
    $(".view-button").click( function(event) {
        event.stopPropagation();
        let $target = $(event.target);
        if ($target.hasClass('view-button')) {
            let nextRow = $target.closest("tr").next();
            if (nextRow.find("div").is(':hidden')) {
                $target.html('<i class="fa fa-minus"></i>')
                nextRow.find("div").show();
            } else {
                $target.html('<i class="fa fa-plus"></i>')
                nextRow.find("div").slideUp('fast');
            }
        }
    })
})
