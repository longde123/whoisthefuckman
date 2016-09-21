module.exports = function(router, model, log) {
    var controllers = {};

    controllers.listAll = function(req, res, next) {
        log.trace("listing all actors");
        model.findAll()
            .then(function(actors) {
                res.json(actors);
            });
    };
    // TODO: this is a debug function
    // disable it for production
    router.get('/', controllers.listAll);

    controllers.add = function(req, res, next) {
        // TODO: validate the request
        model.create({
            name: req.body.name,
            imbd: req.body.imdb
        })
        .then(function(actor) {
            res.json({
                success: true,
                actor: actor
            });
        });
    };
    router.post('/', controllers.add);

    controllers.getMovies = function(req, res, next) {
        var ActorNotFound = {};
        var actor;
        model.findById(req.params.actor_id)
            .then(function(act) {
                if(act == null)
                    throw ActorNotFound;
                actor = act;
                return actor.getMovies();
            })
            .then(function(movies) {
                actor.movies = movies;
                res.json({
                    success: true,
                    actor: actor,
                });
            })
            .catch(function(error) {
                if(error === ActorNotFound) {
                    res.status(404).json({
                        success: false,
                        message: "actor not found"
                    });
                }
                else
                   next(error);
            });
    };
    router.get('/:actor_id/movies', controllers.getMovies);

    return controllers;
}
