import Controller from "@ember/controller";
import { newActor } from "../models/activity-pub-actor";

export default class AdminPluginsActivityPub extends Controller {
  newActor = newActor;
}
