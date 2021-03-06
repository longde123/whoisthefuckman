package stores;

import haxe.ds.IntMap;
import js.html.XMLHttpRequest;
import js.html.XMLHttpRequestResponseType;
import promhx.haxe.Http;
import jsoni18n.I18n;
import promhx.Deferred;
import promhx.Promise;
import tmdb.MovieSearchResult;
import types.TActor;
import types.TMovie;

class Movies {
	private function new() {}
	public static var changed(default, null):Event = new Event();
	public static var movies(default, null):IntMap<TMovie> = new IntMap<TMovie>();

	public static function findMovies(name:String):Promise<Array<MovieSearchResult>> {
		var d:Deferred<Array<MovieSearchResult>> = new Deferred<Array<MovieSearchResult>>();
		var ret:Array<MovieSearchResult> = new Array<MovieSearchResult>();

		// query TMDB
		tmdb.TMDB.searchMovies(name)
			.then(function(results:Array<MovieSearchResult>) {
				for(result in results) {
					// skip if we already have it in our catalog
					if(movies.exists(result.id))
						continue;
					ret.push(result);
				}

				// finally resolve!
				d.resolve(ret);
			})
			.catchError(function(error:Dynamic) {
				d.throwError(error);
			});

		return d.promise();
	}

    public static function add(movie:MovieSearchResult):Promise<TMovie> {
        var d:Deferred<TMovie> = new Deferred<TMovie>();
        var isNew:Bool = !movies.exists(movie.id);

        if(!isNew) {
            d.throwError('Movie ${movie.title} already exists!');
            return d.promise();
        }

        var xhr:XMLHttpRequest = new XMLHttpRequest();
        xhr.open("POST", Main.apiRoot + '/movie', true);
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.setRequestHeader("Authorization", "Bearer " + Authenticate.token);
        xhr.responseType = XMLHttpRequestResponseType.JSON;
        xhr.onload = function() {
            if(xhr.status >= 200 && xhr.status < 300) {
                // parse it
                var mov:TMovie = cast xhr.response;
                mov.actorIDs = new Array<Int>();

                // store it
                movies.set(mov.id, mov);

                // notify
                changed.trigger();
                d.resolve(mov);
            }
            else {
                d.throwError(xhr.response);
            }
        };
        xhr.onabort = function() { d.throwError('aborted add movie request'); }
        xhr.onerror = function() { d.throwError('failed to get add movie'); }
        xhr.ontimeout = function() { d.throwError('get add movie request timed out!'); }
        xhr.send('id=${movie.id}');

        return d.promise();
    }

	public static function delete(movie:TMovie):Promise<TMovie> {
		var d:Deferred<TMovie> = new Deferred<TMovie>();
		if(!movies.exists(movie.id)) {
			d.throwError('Can\'t delete movie ${movie.title} as it isn\'t in the local db!');
		}

		var xhr:XMLHttpRequest = new XMLHttpRequest();
		xhr.open("DELETE", Main.apiRoot + '/movie/${movie.id}', true);
		xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
		xhr.setRequestHeader("Authorization", "Bearer " + Authenticate.token);
		xhr.responseType = XMLHttpRequestResponseType.JSON;
		xhr.onload = function() {
			if(xhr.status >= 200 && xhr.status < 300) {
				// remove it
				movies.remove(movie.id);

				// notify
				changed.trigger();
				d.resolve(movie);
			}
			else {
				d.throwError(xhr.response);
			}
		};
		xhr.onabort = function() { d.throwError('aborted delete movie request'); }
		xhr.onerror = function() { d.throwError('failed to get delete movie'); }
		xhr.ontimeout = function() { d.throwError('get delete movie request timed out!'); }
		xhr.send();
		return d.promise();
	}

	private static function queryActorIDs(movieID:Int) {
		var xhr:XMLHttpRequest = new XMLHttpRequest();
		xhr.open("GET", Main.apiRoot + '/movie/${movieID}', true);
		xhr.responseType = XMLHttpRequestResponseType.JSON;
		xhr.onload = function() {
			if(xhr.status >= 200 && xhr.status < 300) {
				// parse it
				var actorList:Array<TActor> = cast xhr.response.actors;
				for(actor in actorList) {
					movies.get(movieID).actorIDs.push(actor.id);
				}
				changed.trigger();
			}
			else {
				Main.console.error('Failed to load movie ${movieID}\'s actors!', {
					status: xhr.status,
					response: xhr.response
				});
			}
		};
		xhr.onabort = function() Main.console.warn("aborted movie list request");
		xhr.onerror = function() Main.console.error('failed to get movie list');
		xhr.ontimeout = function() Main.console.error('get movie list request timed out!');
		xhr.send();
	}

	public static function queryAll() {
		var xhr:XMLHttpRequest = new XMLHttpRequest();
		xhr.open("GET", Main.apiRoot + '//movie', true);
		xhr.responseType = XMLHttpRequestResponseType.JSON;
		xhr.onload = function() {
			if(xhr.status >= 200 && xhr.status < 300) {
				// parse it
				var movieList:Array<TMovie> = cast xhr.response;

				// convert it into our dictionary
				movies = new IntMap<TMovie>();
				for(movie in movieList) {
					movie.actorIDs = new Array<Int>();
					movies.set(movie.id, movie);
					queryActorIDs(movie.id);
				}

				Main.console.log('got ${movieList.length} movies from the server!');
				changed.trigger();
			}
			else {
				Main.console.error("Failed to load movie list", {
					status: xhr.status,
					response: xhr.response
				});
			}
		};
		xhr.onabort = function() Main.console.warn("aborted movie list request");
		xhr.onerror = function() Main.console.error('failed to get movie list');
		xhr.ontimeout = function() Main.console.error('get movie list request timed out!');
		xhr.send();
	}

	private static function addActorServer(movie:TMovie, actor:TActor):Promise<TMovie> {
		var d:Deferred<TMovie> = new Deferred<TMovie>();
		var xhr:XMLHttpRequest = new XMLHttpRequest();
		xhr.open("POST", Main.apiRoot + '/movie/${movie.id}/actor', true);
		xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
		xhr.setRequestHeader("Authorization", "Bearer " + Authenticate.token);
		xhr.responseType = XMLHttpRequestResponseType.JSON;
		xhr.onload = function() {
			if(xhr.status >= 200 && xhr.status < 300) {
				// parse it
				var mov:TMovie = cast xhr.response.movie;
				var actors:Array<TActor> = cast xhr.response.actors;

				// specify our linkage
				mov.actorIDs = new Array<Int>();
				for(act in actors) {
					mov.actorIDs.push(act.id);
				}

				// store it
				movies.set(mov.id, mov);

				// notify
				changed.trigger();
				d.resolve(mov);
			}
			else {
				d.throwError(xhr.response);
			}
		};
		xhr.onabort = function() { d.throwError('aborted add actor request'); }
		xhr.onerror = function() { d.throwError('failed to get add actor'); }
		xhr.ontimeout = function() { d.throwError('get add actor request timed out!'); }
		xhr.send('id=${actor.id}');
		return d.promise();
	}

	private static function deleteActorServer(movie:TMovie, actor:TActor):Promise<TMovie> {
		var d:Deferred<TMovie> = new Deferred<TMovie>();
		var xhr:XMLHttpRequest = new XMLHttpRequest();
		xhr.open("DELETE", Main.apiRoot + '/movie/${movie.id}/actor/${actor.id}', true);
		xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
		xhr.setRequestHeader("Authorization", "Bearer " + Authenticate.token);
		xhr.responseType = XMLHttpRequestResponseType.JSON;
		xhr.onload = function() {
			if(xhr.status >= 200 && xhr.status < 300) {
				// parse it
				var mov:TMovie = cast xhr.response.movie;
				var actors:Array<TActor> = cast xhr.response.actors;

				// specify our linkage
				mov.actorIDs = new Array<Int>();
				for(act in actors) {
					mov.actorIDs.push(act.id);
				}

				// store it
				movies.set(mov.id, mov);

				// notify
				changed.trigger();
				d.resolve(mov);
			}
			else {
				d.throwError(xhr.response);
			}
		};
		xhr.onabort = function() { d.throwError('aborted delete actor request'); }
		xhr.onerror = function() { d.throwError('failed to get delete actor'); }
		xhr.ontimeout = function() { d.throwError('get delete actor request timed out!'); }
		xhr.send();
		return d.promise();
	}

	public static function addActor(movie:TMovie, actor:TActor):Promise<TMovie> {
		var d:Deferred<TMovie> = new Deferred<TMovie>();
		var isNew:Bool = !Actors.actors.exists(actor.id);

		if(isNew) {
			Actors.add(actor)
				.pipe(function(act:TActor):Promise<TMovie> {
					return addActorServer(movie, act);
				})
				.then(function(mov:TMovie) {
					d.resolve(mov);
				})
				.catchError(function(error:Dynamic) {
					d.throwError(error);
				});
		}
		else {
			return addActorServer(movie, actor);
		}

		return d.promise();
	}

	public static function deleteActor(movie:TMovie, actor:TActor):Promise<TMovie> {
		var d:Deferred<TMovie> = new Deferred<TMovie>();

		if(!Actors.actors.exists(actor.id)) {
			d.throwError("That actor doesn't even exist!");
		}
		else {
			return deleteActorServer(movie, actor);
		}

		return d.promise();
	}
}